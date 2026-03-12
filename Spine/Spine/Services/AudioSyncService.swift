import Foundation
import Speech
import AVFoundation
import SwiftData
import CoreMedia

// MARK: - Audio Sync Service
// Orchestrates the full pipeline:
// 1. Import user's MP3 into app documents
// 2. Transcribe with SpeechAnalyzer + SpeechTranscriber (iOS 26)
// 3. Extract word-level timings from AttributedString TimeRangeAttribute
// 4. Align ASR words onto canonical EPUB text via WordAlignmentEngine
// 5. Cache ChapterTimings JSON per book

@Observable
final class AudioSyncService {
    
    // MARK: - State
    
    var isProcessing = false
    var progress: Double = 0.0
    var statusMessage = ""
    var errorMessage: String?
    
    // MARK: - Directories
    
    private var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("AudioSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func timingsURL(for bookID: UUID) -> URL {
        audioDirectory.appendingPathComponent("\(bookID.uuidString)_timings.json")
    }
    
    private func audioURL(for bookID: UUID, ext: String = "mp3") -> URL {
        audioDirectory.appendingPathComponent("\(bookID.uuidString).\(ext)")
    }
    
    // MARK: - Import Audio
    
    /// Copy the user-selected audio file into app storage.
    func importAudio(from sourceURL: URL, for book: Book) throws -> URL {
        let ext = sourceURL.pathExtension.lowercased()
        let dest = audioURL(for: book.id, ext: ext)
        
        // Remove existing file if re-importing
        try? FileManager.default.removeItem(at: dest)
        
        // Security-scoped access for file picker results
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw AudioSyncError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }
    
    // MARK: - Check for Cached Timings
    
    func hasCachedTimings(for bookID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: timingsURL(for: bookID).path)
    }
    
    func loadCachedTimings(for bookID: UUID) -> ChapterTimings? {
        let url = timingsURL(for: bookID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ChapterTimings.self, from: data)
    }
    
    func audioFileURL(for bookID: UUID) -> URL? {
        // Try common extensions
        for ext in ["mp3", "m4a", "wav", "aac"] {
            let url = audioURL(for: bookID, ext: ext)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
    
    // MARK: - Full Sync Pipeline
    
    /// Run the complete transcription + alignment pipeline.
    /// This is the iOS equivalent of running `generate_timings.py`.
    func syncAudio(for book: Book) async throws -> ChapterTimings {
        guard let audioFileURL = audioFileURL(for: book.id) else {
            throw AudioSyncError.noAudioFile
        }
        
        isProcessing = true
        progress = 0.0
        errorMessage = nil
        
        defer { isProcessing = false }
        
        do {
            // Step 1: Transcribe with SpeechAnalyzer
            statusMessage = "Preparing speech model…"
            progress = 0.05
            let asrWords = try await transcribeWithSpeechAnalyzer(audioURL: audioFileURL)
            progress = 0.6
            
            // Step 2: Get canonical book text
            statusMessage = "Aligning with book text…"
            let bookText = book.sortedUnits.map { $0.plainText }.joined(separator: " ")
            let bookWords = tokenize(bookText)
            progress = 0.65
            
            // Step 3: Forced alignment
            statusMessage = "Matching \(asrWords.count) words to book…"
            let aligned = WordAlignmentEngine.align(
                bookWords: bookWords,
                asrWords: asrWords
            )
            progress = 0.85
            
            // Step 4: Build timings
            statusMessage = "Building timing map…"
            let timings = WordAlignmentEngine.buildTimings(
                from: aligned,
                bookText: bookText
            )
            progress = 0.95
            
            // Step 5: Cache to disk
            let data = try JSONEncoder().encode(timings)
            try data.write(to: timingsURL(for: book.id))
            
            statusMessage = "Synced \(timings.words.count) words"
            progress = 1.0
            
            AnalyticsService.shared.log(.audioSyncCompleted, properties: [
                "bookTitle": book.title,
                "wordCount": String(timings.words.count),
                "paragraphCount": String(timings.paragraphs.count)
            ])
            
            return timings
            
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Sync failed"
            throw error
        }
    }
    
    // MARK: - SpeechAnalyzer Transcription (iOS 26)
    
    /// Transcribe an audio file using the new SpeechAnalyzer + SpeechTranscriber APIs.
    /// Extracts word-level timestamps from the AttributedString's TimeRangeAttribute.
    private func transcribeWithSpeechAnalyzer(audioURL: URL) async throws -> [TimedWord] {
        // 1. Setup transcriber module
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
            throw AudioSyncError.languageNotSupported
        }
        
        let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)
        
        // 2. Ensure assets are downloaded
        statusMessage = "Downloading speech model…"
        if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installRequest.downloadAndInstall()
        }
        
        // 3. Open audio file
        statusMessage = "Transcribing audio…"
        let audioFile = try AVAudioFile(forReading: audioURL)
        
        // 4. Create analyzer and start processing
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        
        // 5. Collect results
        var allWords: [TimedWord] = []
        var wordIndex = 0
        
        // Start result collection task
        let resultTask = Task {
            var words: [TimedWord] = []
            var idx = 0
            
            for try await result in transcriber.results {
                // result.text is an AttributedString with TimeRangeAttribute per word
                let attributedText = result.text
                let fullText = String(attributedText.characters)
                
                // Extract words with their time ranges from the attributed string
                let extracted = self.extractTimedWords(
                    from: attributedText,
                    startingIndex: idx
                )
                
                words.append(contentsOf: extracted)
                idx += extracted.count
                
                // Update progress based on audio position
                await MainActor.run {
                    self.statusMessage = "Transcribed \(words.count) words…"
                    self.progress = min(0.1 + Double(words.count) / 5000.0 * 0.5, 0.59)
                }
            }
            
            return words
        }
        
        // 6. Run analysis on the audio file
        let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
        
        // 7. Finalize
        if let lastSampleTime {
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            try await analyzer.cancelAndFinishNow()
        }
        
        // 8. Await collected results
        allWords = try await resultTask.value
        
        return allWords
    }
    
    // MARK: - Extract Timed Words from AttributedString
    
    /// Extract individual words with their time ranges from a SpeechTranscriber result's
    /// AttributedString. The text has TimeRangeAttribute spans for each word/segment.
    private func extractTimedWords(
        from attributedText: AttributedString,
        startingIndex: Int
    ) -> [TimedWord] {
        var words: [TimedWord] = []
        var idx = startingIndex
        
        // Iterate through runs of the attributed string
        // Each run with a speechTimeRange attribute corresponds to a timed segment
        for run in attributedText.runs {
            let text = String(attributedText[run.range].characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty else { continue }
            
            // Try to get the time range from the speech attributes
            if let timeRange = run.speechTimeRange {
                let startSeconds = CMTimeGetSeconds(timeRange.start)
                let endSeconds = CMTimeGetSeconds(timeRange.end)
                
                // Split multi-word segments into individual words
                let segmentWords = text.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                if segmentWords.count == 1 {
                    words.append(TimedWord(
                        i: idx,
                        t0: startSeconds,
                        t1: endSeconds,
                        w: segmentWords[0]
                    ))
                    idx += 1
                } else {
                    // Distribute time evenly across words in the segment
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
                // No timing info — add word without timestamps (will be interpolated)
                let segmentWords = text.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                for word in segmentWords {
                    words.append(TimedWord(
                        i: idx,
                        t0: 0,
                        t1: 0,
                        w: word
                    ))
                    idx += 1
                }
            }
        }
        
        return words
    }
    
    // MARK: - Tokenization
    
    /// Simple word tokenizer for book text.
    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Delete Audio
    
    func deleteAudio(for bookID: UUID) {
        // Remove audio file
        for ext in ["mp3", "m4a", "wav", "aac"] {
            try? FileManager.default.removeItem(at: audioURL(for: bookID, ext: ext))
        }
        // Remove timings
        try? FileManager.default.removeItem(at: timingsURL(for: bookID))
    }
}

// MARK: - Errors

enum AudioSyncError: LocalizedError {
    case accessDenied
    case noAudioFile
    case languageNotSupported
    case transcriptionFailed(String)
    case alignmentFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Could not access the selected file."
        case .noAudioFile:
            return "No audio file found for this book."
        case .languageNotSupported:
            return "English speech recognition is not available on this device."
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .alignmentFailed:
            return "Could not align audio with book text."
        }
    }
}

// MARK: - AttributedString Speech Extension

extension AttributedString.Runs.Run {
    /// Access the speech time range attribute if present.
    var speechTimeRange: CMTimeRange? {
        // Access the TimeRangeAttribute from Speech framework
        self[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self]
    }
}
