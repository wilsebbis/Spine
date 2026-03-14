import Foundation

// MARK: - Audio Boilerplate Gater
// Classifies ASR transcript chunks as book-content vs non-book-content.
// Non-book speech (LibriVox disclaimers, chapter announcements, credits)
// is excluded from alignment so highlights don't jitter during playback.
//
// Architecture: ASR chunks → classify → filter → only book-content enters aligner
// During non-book speech, the visual anchor stays at the current position.

// MARK: - Audio Chunk Kind

enum AudioChunkKind: String, Codable {
    case bookContent          // actual narrated book text
    case disclaimer           // "This is a LibriVox recording..."
    case chapterAnnouncement  // "Chapter One" spoken aloud
    case credits              // volunteer credits, sign-off
    case uncertain            // not enough signal to classify
}

// MARK: - Classified Audio Chunk

struct ClassifiedAudioChunk: Identifiable {
    let id = UUID()
    let text: String
    let normalizedText: String
    let startTime: Double
    let endTime: Double
    let kind: AudioChunkKind
    let confidence: Double        // 0.0–1.0
    let bookSimilarity: Double    // similarity to nearest book paragraph
}

// MARK: - Audio Boilerplate Gater

struct AudioBoilerplateGater {
    
    // MARK: - Public API
    
    /// Classify an array of ASR transcript chunks against canonical book text.
    /// Returns classified chunks with book-content vs non-content labels.
    static func classify(
        chunks: [TranscriptChunk],
        bookParagraphs: [String]
    ) -> [ClassifiedAudioChunk] {
        let normalizedParagraphs = bookParagraphs.map { normalizeForMatching($0) }
        
        return chunks.map { chunk in
            let normalized = normalizeForMatching(chunk.text)
            
            // Score against different categories
            let disclaimerScore = disclaimerScore(for: normalized)
            let chapterAnnouncementScore = chapterAnnouncementScore(for: normalized)
            let creditsScore = creditsScore(for: normalized)
            let similarity = bestParagraphSimilarity(
                chunkNormalized: normalized,
                paragraphs: normalizedParagraphs
            )
            
            // Classify
            let (kind, confidence) = classifyChunk(
                disclaimerScore: disclaimerScore,
                chapterScore: chapterAnnouncementScore,
                creditsScore: creditsScore,
                bookSimilarity: similarity
            )
            
            return ClassifiedAudioChunk(
                text: chunk.text,
                normalizedText: normalized,
                startTime: chunk.startTime,
                endTime: chunk.endTime,
                kind: kind,
                confidence: confidence,
                bookSimilarity: similarity
            )
        }
    }
    
    /// Extract only book-content chunks from classified results.
    static func bookContentChunks(
        from classified: [ClassifiedAudioChunk]
    ) -> [ClassifiedAudioChunk] {
        classified.filter { $0.kind == .bookContent }
    }
    
    /// Get time ranges that should be skipped during alignment.
    static func skipRanges(
        from classified: [ClassifiedAudioChunk]
    ) -> [(start: Double, end: Double)] {
        classified
            .filter { $0.kind != .bookContent }
            .map { (start: $0.startTime, end: $0.endTime) }
    }
    
    // MARK: - Disclaimer Scoring
    
    private static func disclaimerScore(for normalized: String) -> Double {
        var score = 0.0
        
        let strongKeywords = [
            "librivox",
            "this is a librivox recording",
            "librivox recording",
            "all librivox recordings are in the public domain",
            "public domain",
            "project gutenberg",
            "gutenberg"
        ]
        
        for keyword in strongKeywords {
            if normalized.contains(keyword) {
                score += 0.6
            }
        }
        
        let mediumKeywords = [
            "recording by",
            "read by",
            "this recording is in the public domain",
            "for more free audiobooks",
            "visit librivox",
            "volunteers"
        ]
        
        for keyword in mediumKeywords {
            if normalized.contains(keyword) {
                score += 0.3
            }
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Chapter Announcement Scoring
    
    private static func chapterAnnouncementScore(for normalized: String) -> Double {
        let wordCount = normalized.components(separatedBy: .whitespaces).count
        
        // Must be short (typically 2-6 words)
        guard wordCount <= 8 else { return 0.0 }
        
        var score = 0.0
        
        // "Chapter One", "Chapter 1", "Book Two", "Part 1"
        let chapterPattern = /^(chapter|book|part|section|act|scene)\s+(\w+)/
        if let _ = try? chapterPattern.firstMatch(in: normalized) {
            score += 0.8
        }
        
        // Just a number/numeral alone
        let numberOnlyPattern = /^(one|two|three|four|five|six|seven|eight|nine|ten|\d+)$/
        if let _ = try? numberOnlyPattern.firstMatch(in: normalized) {
            score += 0.4
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Credits Scoring
    
    private static func creditsScore(for normalized: String) -> Double {
        var score = 0.0
        
        let keywords = [
            "proof listener",
            "proof-listener",
            "meta coordinator",
            "this concludes",
            "end of chapter",
            "end of book",
            "the end",
            "thank you for listening"
        ]
        
        for keyword in keywords {
            if normalized.contains(keyword) {
                score += 0.5
            }
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Book Similarity
    
    /// Find the best Jaccard similarity between a chunk and any book paragraph.
    /// Uses a windowed search for efficiency.
    private static func bestParagraphSimilarity(
        chunkNormalized: String,
        paragraphs: [String]
    ) -> Double {
        let chunkTokens = Set(chunkNormalized.components(separatedBy: .whitespaces)
            .filter { $0.count > 2 })  // skip very short words
        
        guard !chunkTokens.isEmpty else { return 0.0 }
        
        var bestScore = 0.0
        
        for paragraph in paragraphs {
            let paraTokens = Set(paragraph.components(separatedBy: .whitespaces)
                .filter { $0.count > 2 })
            
            guard !paraTokens.isEmpty else { continue }
            
            // Jaccard similarity
            let intersection = chunkTokens.intersection(paraTokens).count
            let union = chunkTokens.union(paraTokens).count
            let score = Double(intersection) / Double(max(union, 1))
            
            bestScore = max(bestScore, score)
            
            // Early exit if we find a strong match
            if bestScore > 0.5 { break }
        }
        
        return bestScore
    }
    
    // MARK: - Classification Decision
    
    private static func classifyChunk(
        disclaimerScore: Double,
        chapterScore: Double,
        creditsScore: Double,
        bookSimilarity: Double
    ) -> (AudioChunkKind, Double) {
        // Strong disclaimer signal
        if disclaimerScore >= 0.5 { return (.disclaimer, disclaimerScore) }
        
        // Credits
        if creditsScore >= 0.5 { return (.credits, creditsScore) }
        
        // Chapter announcement (short utterance matching pattern)
        if chapterScore >= 0.6 { return (.chapterAnnouncement, chapterScore) }
        
        // High similarity to book text → book content
        if bookSimilarity >= 0.15 { return (.bookContent, min(bookSimilarity * 2, 1.0)) }
        
        // Low similarity and no keyword matches → likely non-book
        if bookSimilarity < 0.05 && disclaimerScore == 0 && creditsScore == 0 {
            return (.uncertain, 0.3)
        }
        
        // Default: assume book content with moderate confidence
        return (.bookContent, 0.5)
    }
    
    // MARK: - Normalization
    
    private static func normalizeForMatching(_ text: String) -> String {
        var s = text.lowercased()
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\u{2014}", with: " ")
        
        // Strip most punctuation (keep apostrophes)
        s = String(s.unicodeScalars.filter { char in
            CharacterSet.letters.contains(char) ||
            CharacterSet.decimalDigits.contains(char) ||
            CharacterSet.whitespaces.contains(char) ||
            char == "'"
        })
        
        // Collapse whitespace
        s = s.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return s
    }
}

// MARK: - Transcript Chunk (input from ASR)

struct TranscriptChunk: Identifiable {
    let id = UUID()
    let text: String
    let startTime: Double
    let endTime: Double
    let words: [TimedWord]
    let asrConfidence: Double
}
