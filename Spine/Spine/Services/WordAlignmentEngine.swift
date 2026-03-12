import Foundation

// MARK: - Word Alignment Engine
// Forced alignment of ASR transcript words against canonical book text.
// Uses dynamic programming to map recognized words onto real book words,
// transferring timestamps while correcting ASR errors.
//
// This is the key layer that makes it "Apple Music lyrics" instead of
// "subtitle blobs" — the canonical EPUB text is always what's displayed.

struct WordAlignmentEngine {
    
    // MARK: - Alignment Result
    
    struct AlignedWord {
        let bookWordIndex: Int
        let bookWord: String
        let startTime: Double?
        let endTime: Double?
        let confidence: AlignmentConfidence
    }
    
    enum AlignmentConfidence {
        case exact          // ASR word matches book word exactly
        case fuzzy          // close match (edit distance ≤ 2)
        case interpolated   // no match, time estimated from neighbors
    }
    
    // MARK: - Public API
    
    /// Align ASR-recognized words (with timestamps) against canonical book text.
    /// Returns one AlignedWord per canonical book word with transferred timestamps.
    static func align(
        bookWords: [String],
        asrWords: [TimedWord]
    ) -> [AlignedWord] {
        let normBook = bookWords.map { normalize($0) }
        let normASR = asrWords.map { normalize($0.w) }
        
        // DP alignment
        let alignment = dpAlign(reference: normBook, hypothesis: normASR)
        
        // Transfer timestamps from ASR to book words
        var result: [AlignedWord] = []
        
        for (bookIdx, asrIdx) in alignment {
            if let asrIdx = asrIdx, asrIdx < asrWords.count {
                let asr = asrWords[asrIdx]
                let conf: AlignmentConfidence = normBook[bookIdx] == normASR[asrIdx]
                    ? .exact : .fuzzy
                result.append(AlignedWord(
                    bookWordIndex: bookIdx,
                    bookWord: bookWords[bookIdx],
                    startTime: asr.t0,
                    endTime: asr.t1,
                    confidence: conf
                ))
            } else {
                result.append(AlignedWord(
                    bookWordIndex: bookIdx,
                    bookWord: bookWords[bookIdx],
                    startTime: nil,
                    endTime: nil,
                    confidence: .interpolated
                ))
            }
        }
        
        // Interpolate missing timestamps from neighbors
        return interpolateGaps(result)
    }
    
    /// Convert aligned words into the final ChapterTimings format.
    static func buildTimings(
        from alignedWords: [AlignedWord],
        bookText: String
    ) -> ChapterTimings {
        // Build timed words
        let timedWords = alignedWords.compactMap { aligned -> TimedWord? in
            guard let t0 = aligned.startTime, let t1 = aligned.endTime else {
                return nil
            }
            return TimedWord(
                i: aligned.bookWordIndex,
                t0: t0,
                t1: t1,
                w: aligned.bookWord
            )
        }
        
        // Build paragraphs from sentence boundaries
        let paragraphs = buildParagraphs(
            from: timedWords,
            bookText: bookText
        )
        
        return ChapterTimings(words: timedWords, paragraphs: paragraphs)
    }
    
    // MARK: - DP Alignment
    
    /// Dynamic programming alignment of two word sequences.
    /// Returns array of (bookIndex, asrIndex?) pairs.
    private static func dpAlign(
        reference: [String],
        hypothesis: [String]
    ) -> [(Int, Int?)] {
        let n = reference.count
        let m = hypothesis.count
        
        guard n > 0 && m > 0 else {
            return reference.indices.map { ($0, nil) }
        }
        
        // Score matrix
        // dp[i][j] = best score aligning reference[0..<i] with hypothesis[0..<j]
        var dp = Array(
            repeating: Array(repeating: Int.min / 2, count: m + 1),
            count: n + 1
        )
        dp[0][0] = 0
        
        // Backtrack matrix: 0 = match/sub, 1 = delete (skip ref), 2 = insert (skip hyp)
        var bt = Array(
            repeating: Array(repeating: 0, count: m + 1),
            count: n + 1
        )
        
        // Initialize
        for i in 1...n { dp[i][0] = -i; bt[i][0] = 1 }
        for j in 1...m { dp[0][j] = -j; bt[0][j] = 2 }
        
        // Fill
        let matchScore = 3
        let fuzzyScore = 1
        let mismatchPenalty = -2
        let gapPenalty = -1
        
        for i in 1...n {
            for j in 1...m {
                let refWord = reference[i - 1]
                let hypWord = hypothesis[j - 1]
                
                let score: Int
                if refWord == hypWord {
                    score = matchScore
                } else if editDistance(refWord, hypWord) <= 2 {
                    score = fuzzyScore
                } else {
                    score = mismatchPenalty
                }
                
                let diag = dp[i - 1][j - 1] + score
                let del = dp[i - 1][j] + gapPenalty
                let ins = dp[i][j - 1] + gapPenalty
                
                if diag >= del && diag >= ins {
                    dp[i][j] = diag; bt[i][j] = 0
                } else if del >= ins {
                    dp[i][j] = del; bt[i][j] = 1
                } else {
                    dp[i][j] = ins; bt[i][j] = 2
                }
            }
        }
        
        // Backtrace
        var result: [(Int, Int?)] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && bt[i][j] == 0 {
                // Match or substitution → pair them
                let refWord = reference[i - 1]
                let hypWord = hypothesis[j - 1]
                let isMatch = refWord == hypWord || editDistance(refWord, hypWord) <= 2
                result.append((i - 1, isMatch ? j - 1 : nil))
                i -= 1; j -= 1
            } else if i > 0 && (j == 0 || bt[i][j] == 1) {
                // Deletion — book word has no ASR match
                result.append((i - 1, nil))
                i -= 1
            } else {
                // Insertion — ASR word has no book match (skip)
                j -= 1
            }
        }
        
        return result.reversed()
    }
    
    // MARK: - Normalization
    
    /// Normalize a word for matching: lowercase, strip punctuation,
    /// normalize quotes/apostrophes.
    static func normalize(_ word: String) -> String {
        var s = word.lowercased()
        
        // Normalize quotes and apostrophes
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\u{201C}", with: "\"")
        s = s.replacingOccurrences(of: "\u{201D}", with: "\"")
        
        // Strip punctuation (keep apostrophes for contractions)
        s = String(s.unicodeScalars.filter { char in
            CharacterSet.letters.contains(char) ||
            CharacterSet.decimalDigits.contains(char) ||
            char == "'"
        })
        
        return s
    }
    
    // MARK: - Edit Distance
    
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let n = a.count, m = b.count
        
        guard n > 0 else { return m }
        guard m > 0 else { return n }
        
        var prev = Array(0...m)
        var curr = Array(repeating: 0, count: m + 1)
        
        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j - 1], prev[j], curr[j - 1])
                }
            }
            prev = curr
        }
        return prev[m]
    }
    
    // MARK: - Interpolation
    
    /// Fill in missing timestamps by interpolating from neighboring matched words.
    private static func interpolateGaps(_ words: [AlignedWord]) -> [AlignedWord] {
        var result = words
        
        // Find runs of .interpolated words and fill from neighbors
        var i = 0
        while i < result.count {
            if result[i].confidence == .interpolated {
                // Find the gap bounds
                let gapStart = i
                var gapEnd = i
                while gapEnd < result.count && result[gapEnd].confidence == .interpolated {
                    gapEnd += 1
                }
                
                // Get boundary times
                let prevEnd = gapStart > 0 ? result[gapStart - 1].endTime : 0.0
                let nextStart = gapEnd < result.count ? result[gapEnd].startTime : prevEnd
                
                guard let t0 = prevEnd, let t1 = nextStart else {
                    i = gapEnd
                    continue
                }
                
                // Distribute time evenly across gap
                let gapCount = gapEnd - gapStart
                let duration = (t1 - t0) / Double(gapCount)
                
                for j in gapStart..<gapEnd {
                    let offset = Double(j - gapStart)
                    result[j] = AlignedWord(
                        bookWordIndex: result[j].bookWordIndex,
                        bookWord: result[j].bookWord,
                        startTime: t0 + offset * duration,
                        endTime: t0 + (offset + 1) * duration,
                        confidence: .interpolated
                    )
                }
                
                i = gapEnd
            } else {
                i += 1
            }
        }
        
        return result
    }
    
    // MARK: - Paragraph Building
    
    /// Group words into phrases/paragraphs based on natural text boundaries.
    private static func buildParagraphs(
        from words: [TimedWord],
        bookText: String
    ) -> [TimedPhrase] {
        guard !words.isEmpty else { return [] }
        
        var paragraphs: [TimedPhrase] = []
        var paraStart = 0
        
        // Split at sentence boundaries (roughly every 15-25 words,
        // or at sentence-ending punctuation)
        for (idx, word) in words.enumerated() {
            let isEnd = word.w.hasSuffix(".") || word.w.hasSuffix("!") ||
                        word.w.hasSuffix("?") || word.w.hasSuffix("\"")
            let wordsInPara = idx - paraStart + 1
            
            if (isEnd && wordsInPara >= 8) || wordsInPara >= 25 {
                paragraphs.append(TimedPhrase(start: paraStart, end: idx))
                paraStart = idx + 1
            }
        }
        
        // Final paragraph
        if paraStart < words.count {
            paragraphs.append(TimedPhrase(
                start: paraStart,
                end: words.count - 1
            ))
        }
        
        return paragraphs
    }
}
