import Foundation
import SwiftData
import Speech
import AVFoundation

// MARK: - Audiobook Alignment Service
// Orchestrates the full multi-chapter alignment pipeline:
// 1. Map audiobook chapters → EPUB chapters (ordinal + title fuzzy match)
// 2. For each pair: classify text blocks → get canonical text
// 3. Transcribe MP3 with SpeechTranscriber → gate boilerplate
// 4. Align filtered ASR words against canonical EPUB text
// 5. Store per-chapter ChapterTimings on AudiobookChapter model
//
// Uses existing AudioSyncService for transcription and WordAlignmentEngine for alignment.

@MainActor
@Observable
final class AudiobookAlignmentService {
    
    // MARK: - State
    
    enum AlignmentState: Equatable {
        case idle
        case preparing
        case transcribing(chapter: Int, total: Int)
        case aligning(chapter: Int, total: Int)
        case completed(chaptersAligned: Int)
        case failed(String)
    }
    
    var state: AlignmentState = .idle
    var progress: Double = 0.0
    var currentChapterTitle: String = ""
    
    private let modelContext: ModelContext
    private let audioSyncService = AudioSyncService()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public API
    
    /// Run the full alignment pipeline for a book with both EPUB and audiobook.
    /// Maps audiobook chapters to EPUB chapters, transcribes each, and aligns.
    func alignBook(_ book: Book) async {
        guard book.isDownloaded && book.hasAudiobook else {
            state = .failed("Book needs both EPUB and audiobook downloaded")
            return
        }
        
        let epubChapters = book.chapters.sorted { $0.ordinal < $1.ordinal }
        let audioChapters = book.sortedAudioChapters.filter { $0.isDownloaded }
        
        guard !epubChapters.isEmpty && !audioChapters.isEmpty else {
            state = .failed("No chapters available")
            return
        }
        
        state = .preparing
        progress = 0.0
        
        // Step 1: Map audiobook chapters → EPUB chapters
        let mapping = mapChapters(
            audio: audioChapters,
            epub: epubChapters
        )
        
        let total = mapping.count
        var alignedCount = 0
        
        // Step 2: Classify EPUB text and build canonical text per chapter
        let canonicalTexts = buildCanonicalTexts(chapters: epubChapters)
        
        // Step 3: Process each mapped pair
        for (index, pair) in mapping.enumerated() {
            let audioChapter = pair.audioChapter
            let epubChapter = pair.epubChapter
            
            currentChapterTitle = audioChapter.title.isEmpty
                ? "Chapter \(audioChapter.ordinal)"
                : audioChapter.title
            
            // Skip if already aligned with good confidence
            if audioChapter.alignmentConfidence > 0.5 && audioChapter.timingsData != nil {
                alignedCount += 1
                continue
            }
            
            guard let audioURL = audioChapter.localFileURL else { continue }
            
            // Step 3a: Transcribe
            state = .transcribing(chapter: index + 1, total: total)
            progress = Double(index) / Double(total)
            
            do {
                let asrWords = try await transcribeChapter(audioURL: audioURL)
                
                // Store raw transcript
                audioChapter.transcriptText = asrWords.map { $0.w }.joined(separator: " ")
                
                // Step 3b: Gate boilerplate
                let canonicalText = canonicalTexts[epubChapter.ordinal] ?? epubChapter.plainText
                let chunks = buildTranscriptChunks(from: asrWords)
                let paragraphs = canonicalText.components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                let classifiedChunks = AudioBoilerplateGater.classify(
                    chunks: chunks,
                    bookParagraphs: paragraphs
                )
                
                // Filter to book content only
                let bookContentWords = filterToBookContent(
                    allWords: asrWords,
                    classifiedChunks: classifiedChunks
                )
                
                // Step 3c: Align
                state = .aligning(chapter: index + 1, total: total)
                
                let bookWords = tokenize(canonicalText)
                let aligned = WordAlignmentEngine.align(
                    bookWords: bookWords,
                    asrWords: bookContentWords
                )
                
                let timings = WordAlignmentEngine.buildTimings(
                    from: aligned,
                    bookText: canonicalText
                )
                
                // Step 3d: Store results
                audioChapter.timings = timings
                audioChapter.matchedEpubChapterOrdinal = epubChapter.ordinal
                audioChapter.alignmentConfidence = computeConfidence(aligned: aligned)
                
                // Compute start offset from boilerplate gating
                let skipRanges = AudioBoilerplateGater.skipRanges(from: classifiedChunks)
                if let firstBookContent = classifiedChunks.first(where: { $0.kind == .bookContent }) {
                    audioChapter.startOffset = firstBookContent.startTime
                }
                
                alignedCount += 1
                
            } catch {
                // Log but continue with other chapters
                print("⚠️ Alignment failed for chapter \(audioChapter.ordinal): \(error)")
                audioChapter.alignmentConfidence = 0
            }
            
            progress = Double(index + 1) / Double(total)
        }
        
        // Save all changes
        try? modelContext.save()
        
        state = .completed(chaptersAligned: alignedCount)
        
        AnalyticsService.shared.log(.audioSyncCompleted, properties: [
            "bookTitle": book.title,
            "chaptersAligned": String(alignedCount),
            "totalChapters": String(total)
        ])
    }
    
    /// Check if a book has alignment data available.
    static func hasAlignment(for book: Book) -> Bool {
        book.sortedAudioChapters.contains { $0.timingsData != nil }
    }
    
    /// Get timings for a specific audiobook chapter.
    static func timings(for audioChapter: AudiobookChapter) -> ChapterTimings? {
        audioChapter.timings
    }
    
    // MARK: - Chapter Mapping
    
    struct ChapterMapping {
        let audioChapter: AudiobookChapter
        let epubChapter: Chapter
        let matchConfidence: Double
    }
    
    /// Map audiobook chapters to EPUB chapters.
    /// Uses ordinal matching first, then title fuzzy matching as fallback.
    private func mapChapters(
        audio: [AudiobookChapter],
        epub: [Chapter]
    ) -> [ChapterMapping] {
        var mapping: [ChapterMapping] = []
        
        for audioChapter in audio {
            // Strategy 1: Match by ordinal
            if let match = epub.first(where: { $0.ordinal == audioChapter.ordinal }) {
                mapping.append(ChapterMapping(
                    audioChapter: audioChapter,
                    epubChapter: match,
                    matchConfidence: 0.8
                ))
                continue
            }
            
            // Strategy 2: Fuzzy title match
            if let match = bestTitleMatch(audioTitle: audioChapter.title, epubChapters: epub) {
                mapping.append(ChapterMapping(
                    audioChapter: audioChapter,
                    epubChapter: match.chapter,
                    matchConfidence: match.score
                ))
                continue
            }
            
            // Strategy 3: Closest ordinal
            if let closest = epub.min(by: {
                abs($0.ordinal - audioChapter.ordinal) < abs($1.ordinal - audioChapter.ordinal)
            }) {
                mapping.append(ChapterMapping(
                    audioChapter: audioChapter,
                    epubChapter: closest,
                    matchConfidence: 0.3
                ))
            }
        }
        
        return mapping
    }
    
    private func bestTitleMatch(
        audioTitle: String,
        epubChapters: [Chapter]
    ) -> (chapter: Chapter, score: Double)? {
        let normalizedAudio = audioTitle.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !normalizedAudio.isEmpty else { return nil }
        
        var best: (Chapter, Double)?
        
        for chapter in epubChapters {
            let normalizedEpub = chapter.title.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            guard !normalizedEpub.isEmpty else { continue }
            
            let audioSet = Set(normalizedAudio)
            let epubSet = Set(normalizedEpub)
            let intersection = audioSet.intersection(epubSet).count
            let union = audioSet.union(epubSet).count
            let score = Double(intersection) / Double(max(union, 1))
            
            if score > (best?.1 ?? 0.3) {
                best = (chapter, score)
            }
        }
        
        return best.map { ($0.0, $0.1) }
    }
    
    // MARK: - Canonical Text Building
    
    /// Build canonical (cleaned) text for each EPUB chapter using the block classifier.
    private func buildCanonicalTexts(chapters: [Chapter]) -> [Int: String] {
        var result: [Int: String] = [:]
        
        for chapter in chapters {
            let blocks = TextBlockClassifier.splitIntoBlocks(chapter.plainText)
            let classified = TextBlockClassifier.classify(blocks: blocks)
            let canonical = TextBlockClassifier.canonicalText(from: classified)
            result[chapter.ordinal] = canonical.isEmpty ? chapter.plainText : canonical
        }
        
        return result
    }
    
    // MARK: - Transcription
    
    /// Transcribe a single audiobook chapter MP3 using SpeechTranscriber.
    private func transcribeChapter(audioURL: URL) async throws -> [TimedWord] {
        // Reuse the SpeechTranscriber pipeline from AudioSyncService
        guard let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: Locale(identifier: "en-US")
        ) else {
            throw AudioSyncError.languageNotSupported
        }
        
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedTranscriptionWithAlternatives
        )
        
        // Ensure assets are downloaded
        if let installRequest = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            try await installRequest.downloadAndInstall()
        }
        
        let audioFile = try AVAudioFile(forReading: audioURL)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        
        var allWords: [TimedWord] = []
        var wordIndex = 0
        
        let resultTask = Task {
            var words: [TimedWord] = []
            var idx = 0
            
            for try await result in transcriber.results {
                let attributedText = result.text
                
                for run in attributedText.runs {
                    let text = String(attributedText[run.range].characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard !text.isEmpty else { continue }
                    
                    if let timeRange = run.speechTimeRange {
                        let startSeconds = CMTimeGetSeconds(timeRange.start)
                        let endSeconds = CMTimeGetSeconds(timeRange.end)
                        
                        let segmentWords = text.components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        
                        if segmentWords.count == 1 {
                            words.append(TimedWord(i: idx, t0: startSeconds, t1: endSeconds, w: segmentWords[0]))
                            idx += 1
                        } else {
                            let duration = endSeconds - startSeconds
                            let perWord = duration / Double(segmentWords.count)
                            for (j, word) in segmentWords.enumerated() {
                                words.append(TimedWord(
                                    i: idx,
                                    t0: startSeconds + Double(j) * perWord,
                                    t1: startSeconds + Double(j + 1) * perWord,
                                    w: word
                                ))
                                idx += 1
                            }
                        }
                    } else {
                        let segmentWords = text.components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        for word in segmentWords {
                            words.append(TimedWord(i: idx, t0: 0, t1: 0, w: word))
                            idx += 1
                        }
                    }
                }
            }
            return words
        }
        
        let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
        if let lastSampleTime {
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            try await analyzer.cancelAndFinishNow()
        }
        
        allWords = try await resultTask.value
        return allWords
    }
    
    // MARK: - Transcript Chunking
    
    /// Group ASR words into ~5-second chunks for boilerplate classification.
    private func buildTranscriptChunks(from words: [TimedWord]) -> [TranscriptChunk] {
        guard !words.isEmpty else { return [] }
        
        var chunks: [TranscriptChunk] = []
        let chunkDuration = 5.0  // seconds per chunk
        
        var chunkStart = words[0].t0
        var chunkWords: [TimedWord] = []
        
        for (wordIdx, word) in words.enumerated() {
            chunkWords.append(word)
            
            if word.t1 - chunkStart >= chunkDuration || wordIdx == words.count - 1 {
                let text = chunkWords.map { $0.w }.joined(separator: " ")
                chunks.append(TranscriptChunk(
                    text: text,
                    startTime: chunkStart,
                    endTime: word.t1,
                    words: chunkWords,
                    asrConfidence: 1.0
                ))
                chunkStart = word.t1
                chunkWords = []
            }
        }
        
        // Flush remaining words
        if !chunkWords.isEmpty {
            let text = chunkWords.map { $0.w }.joined(separator: " ")
            chunks.append(TranscriptChunk(
                text: text,
                startTime: chunkStart,
                endTime: chunkWords.last!.t1,
                words: chunkWords,
                asrConfidence: 1.0
            ))
        }
        
        return chunks
    }
    
    // MARK: - Book Content Filtering
    
    /// Filter ASR words to only include those in book-content chunks.
    private func filterToBookContent(
        allWords: [TimedWord],
        classifiedChunks: [ClassifiedAudioChunk]
    ) -> [TimedWord] {
        let skipRanges = AudioBoilerplateGater.skipRanges(from: classifiedChunks)
        
        return allWords.filter { word in
            !skipRanges.contains { range in
                word.t0 >= range.start && word.t0 < range.end
            }
        }
    }
    
    // MARK: - Confidence Computation
    
    /// Compute overall alignment confidence from individual word confidences.
    private func computeConfidence(aligned: [WordAlignmentEngine.AlignedWord]) -> Double {
        guard !aligned.isEmpty else { return 0.0 }
        
        let exactCount = aligned.filter { $0.confidence == .exact }.count
        let fuzzyCount = aligned.filter { $0.confidence == .fuzzy }.count
        let interpolatedCount = aligned.filter { $0.confidence == .interpolated }.count
        
        let total = Double(aligned.count)
        return (Double(exactCount) * 1.0 + Double(fuzzyCount) * 0.7 + Double(interpolatedCount) * 0.2) / total
    }
    
    // MARK: - Tokenization
    
    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
