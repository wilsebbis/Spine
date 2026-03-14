import Foundation

// MARK: - Text Block Classifier
// Classifies text blocks from EPUB content into semantic categories.
// Uses rule-based heuristics to separate body text from boilerplate,
// TOC, headings, front/back matter, and credits.
//
// Architecture: raw EPUB → classified blocks → canonical reading stream
// The classifier produces reversible labels — raw text is never mutated.

// MARK: - Block Kind

enum BlockKind: String, Codable {
    case bodyText
    case chapterHeading
    case tableOfContents
    case frontMatter
    case boilerplate
    case credits
    case backMatter
    case uncertain
}

// MARK: - Classified Block

struct ClassifiedBlock: Identifiable {
    let id = UUID()
    let rawText: String
    let normalizedText: String
    let kind: BlockKind
    let shouldRender: Bool      // display inline to reader
    let shouldSync: Bool        // use for audio alignment
    let confidence: Double      // 0.0–1.0
    let sourceIndex: Int        // position in original document
    
    /// Metadata extracted from headings
    var chapterNumber: Int?
    var headingTitle: String?
}

// MARK: - Text Block Classifier

struct TextBlockClassifier {
    
    // MARK: - Public API
    
    /// Classify raw text blocks from an EPUB chapter.
    /// Input: array of paragraph-level text blocks (split by blank lines).
    /// Output: classified blocks with labels and render/sync decisions.
    static func classify(blocks: [String]) -> [ClassifiedBlock] {
        var results: [ClassifiedBlock] = []
        let normalized = blocks.map { normalizeForClassification($0) }
        
        // First pass: score each block
        for (index, raw) in blocks.enumerated() {
            let norm = normalized[index]
            
            let boilerplateScore = boilerplateScore(for: norm)
            let tocScore = tocScore(for: raw, normalized: norm)
            let headingScore = headingScore(for: raw, normalized: norm)
            let proseScore = proseScore(for: raw, normalized: norm)
            
            // Classify by highest score
            let (kind, confidence) = classifyByScores(
                boilerplate: boilerplateScore,
                toc: tocScore,
                heading: headingScore,
                prose: proseScore
            )
            
            // Extract heading metadata
            var chapterNumber: Int?
            var headingTitle: String?
            if kind == .chapterHeading {
                (chapterNumber, headingTitle) = extractHeadingMetadata(from: raw)
            }
            
            var block = ClassifiedBlock(
                rawText: raw,
                normalizedText: norm,
                kind: kind,
                shouldRender: kind == .bodyText || kind == .frontMatter,
                shouldSync: kind == .bodyText,
                confidence: confidence,
                sourceIndex: index
            )
            block.chapterNumber = chapterNumber
            block.headingTitle = headingTitle
            
            results.append(block)
        }
        
        // Second pass: find "main body start" — first sustained run of prose
        let bodyStartIndex = findMainBodyStart(in: results)
        
        // Mark everything before body start as front matter (if not already boilerplate/toc)
        for i in 0..<min(bodyStartIndex, results.count) {
            if results[i].kind == .uncertain || results[i].kind == .bodyText {
                let old = results[i]
                results[i] = ClassifiedBlock(
                    rawText: old.rawText,
                    normalizedText: old.normalizedText,
                    kind: .frontMatter,
                    shouldRender: false,
                    shouldSync: false,
                    confidence: 0.7,
                    sourceIndex: old.sourceIndex
                )
            }
        }
        
        return results
    }
    
    /// Extract only the canonical reading text (body paragraphs).
    static func canonicalText(from blocks: [ClassifiedBlock]) -> String {
        blocks
            .filter { $0.shouldSync }
            .map { $0.rawText }
            .joined(separator: "\n\n")
    }
    
    /// Split raw chapter text into blocks (paragraph-level).
    static func splitIntoBlocks(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Normalization
    
    /// Normalize text for classification (not for display).
    private static func normalizeForClassification(_ text: String) -> String {
        var s = text.lowercased()
        
        // Normalize quotes/apostrophes
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\u{201C}", with: "\"")
        s = s.replacingOccurrences(of: "\u{201D}", with: "\"")
        s = s.replacingOccurrences(of: "\u{2014}", with: "--")  // em dash
        s = s.replacingOccurrences(of: "\u{2013}", with: "-")   // en dash
        
        // Collapse whitespace
        s = s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Boilerplate Scoring
    
    /// Score how likely a block is to be boilerplate (0.0–1.0).
    private static func boilerplateScore(for normalized: String) -> Double {
        var score = 0.0
        
        // Strong indicators (high weight)
        let strongKeywords = [
            "project gutenberg",
            "gutenberg ebook",
            "this ebook is for the use of anyone anywhere",
            "end of the project gutenberg",
            "end of project gutenberg",
            "*** start of",
            "*** end of",
            "start of this project gutenberg",
            "terms of the project gutenberg license"
        ]
        
        for keyword in strongKeywords {
            if normalized.contains(keyword) {
                score += 0.5
            }
        }
        
        // LibriVox indicators
        let librivoxKeywords = [
            "librivox",
            "this librivox recording",
            "librivox recordings are in the public domain",
            "recording by",
            "read by",
            "proof-listener",
            "proof listener",
            "meta coordinator"
        ]
        
        for keyword in librivoxKeywords {
            if normalized.contains(keyword) {
                score += 0.5
            }
        }
        
        // Production/source indicators (medium weight)
        let mediumKeywords = [
            "online distributed proofreading",
            "produced by",
            "transcribed from",
            "scanned by",
            "digitized by",
            "this work is in the public domain",
            "public domain in the united states",
            "distributed proofreading team"
        ]
        
        for keyword in mediumKeywords {
            if normalized.contains(keyword) {
                score += 0.3
            }
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - TOC Scoring
    
    /// Score how likely a block is to be a table of contents (0.0–1.0).
    private static func tocScore(for raw: String, normalized: String) -> Double {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count >= 3 else { return 0.0 }
        
        var score = 0.0
        
        // Header check
        if normalized.hasPrefix("contents") || normalized.hasPrefix("table of contents") {
            score += 0.4
        }
        
        // Dot leaders: ..... or . . . .
        let dotLeaderLines = lines.filter {
            $0.contains("...") || $0.contains(". . .")
        }
        if Double(dotLeaderLines.count) / Double(lines.count) > 0.3 {
            score += 0.3
        }
        
        // Lines ending in digits or roman numerals
        let romanPattern = /[IVXLCDM]+$/
        let digitEndLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.last?.isNumber == true ||
                   (try? romanPattern.firstMatch(in: trimmed)) != nil
        }
        if Double(digitEndLines.count) / Double(lines.count) > 0.3 {
            score += 0.3
        }
        
        // Short average line length (TOC lines are typically short)
        let avgLineLength = lines.reduce(0) { $0 + $1.count } / max(lines.count, 1)
        if avgLineLength < 60 && lines.count > 4 {
            score += 0.1
        }
        
        // Many lines starting with "chapter" or "book"
        let chapterLines = lines.filter {
            let lower = $0.lowercased()
            return lower.hasPrefix("chapter") || lower.hasPrefix("book") ||
                   lower.hasPrefix("part") || lower.hasPrefix("act")
        }
        if Double(chapterLines.count) / Double(lines.count) > 0.3 {
            score += 0.2
        }
        
        // Low sentence-ending punctuation (TOC doesn't have prose sentences)
        let sentenceEnders = normalized.filter { ".!?".contains($0) }.count
        let wordCount = normalized.components(separatedBy: .whitespaces).count
        if wordCount > 10 && Double(sentenceEnders) / Double(wordCount) < 0.02 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Heading Scoring
    
    /// Score how likely a block is to be a chapter heading (0.0–1.0).
    private static func headingScore(for raw: String, normalized: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count <= 3 else { return 0.0 }  // headings are short
        
        let wordCount = normalized.components(separatedBy: .whitespaces).count
        guard wordCount <= 15 else { return 0.0 }  // headings are brief
        
        var score = 0.0
        
        // Chapter/book/part patterns
        let chapterPattern = /^(chapter|book|part|section|act|scene|volume)\s+([ivxlcdm]+|\d+)/
        if let _ = try? chapterPattern.firstMatch(in: normalized) {
            score += 0.7
        }
        
        // All-caps detection
        let letters = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let uppercaseLetters = letters.filter { CharacterSet.uppercaseLetters.contains($0) }
        if letters.count > 3 && Double(uppercaseLetters.count) / Double(letters.count) > 0.8 {
            score += 0.3
        }
        
        // Very short (1-5 words) isolated block
        if wordCount <= 5 {
            score += 0.1
        }
        
        // Roman numeral only line
        let romanOnlyPattern = /^[IVXLCDM]+\.?$/
        if let _ = try? romanOnlyPattern.firstMatch(in: trimmed) {
            score += 0.5
        }
        
        // Numbered chapter: "1." or "I."
        let numberedPattern = /^\d+\.?$|^[IVXLCDM]+\.$/
        if let _ = try? numberedPattern.firstMatch(in: trimmed) {
            score += 0.4
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Prose Scoring
    
    /// Score how likely a block is to be body text prose (0.0–1.0).
    private static func proseScore(for raw: String, normalized: String) -> Double {
        let wordCount = normalized.components(separatedBy: .whitespaces).count
        
        guard wordCount >= 5 else { return 0.1 }
        
        var score = 0.0
        
        // Sentence-ending punctuation
        let sentenceEnders = normalized.filter { ".!?".contains($0) }.count
        if sentenceEnders > 0 {
            score += 0.3
        }
        
        // Stopword density (prose has lots of stop words)
        let stopwords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "of", "to", "for",
            "is", "was", "were", "are", "been", "be", "have", "has", "had",
            "do", "did", "does", "will", "would", "could", "should", "may",
            "might", "shall", "can", "it", "he", "she", "they", "we", "you",
            "i", "my", "his", "her", "their", "our", "your", "its",
            "this", "that", "these", "those", "with", "from", "at", "by",
            "on", "not", "no", "as", "if", "so", "than", "then", "when",
            "what", "which", "who", "whom", "how", "all", "each", "every",
            "very", "just", "only", "also", "more", "most", "some", "any"
        ]
        let words = normalized.components(separatedBy: .whitespaces)
        let stopwordCount = words.filter { stopwords.contains($0) }.count
        let stopwordRatio = Double(stopwordCount) / Double(max(wordCount, 1))
        
        if stopwordRatio > 0.3 {
            score += 0.3
        }
        
        // Minimum length for prose
        if wordCount >= 20 {
            score += 0.2
        }
        
        // Contains commas (prose typically has more internal punctuation)
        if normalized.contains(",") {
            score += 0.1
        }
        
        // Not too many uppercase-starting words relative to total (not a list)
        let capsWords = words.filter { $0.first?.isUppercase == true }.count
        let capsRatio = Double(capsWords) / Double(max(wordCount, 1))
        if capsRatio < 0.5 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Classification Decision
    
    private static func classifyByScores(
        boilerplate: Double,
        toc: Double,
        heading: Double,
        prose: Double
    ) -> (BlockKind, Double) {
        // Hard thresholds first
        if boilerplate >= 0.5 { return (.boilerplate, boilerplate) }
        if toc >= 0.6 { return (.tableOfContents, toc) }
        if heading >= 0.6 { return (.chapterHeading, heading) }
        if prose >= 0.5 { return (.bodyText, prose) }
        
        // Soft comparison — pick highest
        let scores: [(BlockKind, Double)] = [
            (.boilerplate, boilerplate),
            (.tableOfContents, toc),
            (.chapterHeading, heading),
            (.bodyText, prose)
        ]
        
        if let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0.3 {
            return best
        }
        
        return (.uncertain, 0.0)
    }
    
    // MARK: - Heading Metadata Extraction
    
    /// Extract chapter number and title from a heading block.
    private static func extractHeadingMetadata(from raw: String) -> (Int?, String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // Pattern: "Chapter 1" or "CHAPTER I" or "Chapter 1. Title"
        let pattern = /^(chapter|book|part|section)\s+([ivxlcdm]+|\d+)[\.\-:\s]*(.*)/
        if let match = try? pattern.firstMatch(in: lower) {
            let numStr = String(match.2)
            let number = parseChapterNumber(numStr)
            let title = String(match.3).trimmingCharacters(in: .whitespacesAndNewlines)
            return (number, title.isEmpty ? nil : title)
        }
        
        return (nil, trimmed.count <= 80 ? trimmed : nil)
    }
    
    /// Parse a chapter number from either arabic or roman numeral string.
    private static func parseChapterNumber(_ str: String) -> Int? {
        // Try arabic first
        if let num = Int(str) { return num }
        
        // Try roman numeral
        return romanToInt(str.uppercased())
    }
    
    /// Convert roman numeral to integer.
    private static func romanToInt(_ s: String) -> Int? {
        let values: [Character: Int] = [
            "I": 1, "V": 5, "X": 10, "L": 50,
            "C": 100, "D": 500, "M": 1000
        ]
        
        var result = 0
        var prev = 0
        
        for char in s.reversed() {
            guard let value = values[char] else { return nil }
            if value < prev {
                result -= value
            } else {
                result += value
            }
            prev = value
        }
        
        return result > 0 ? result : nil
    }
    
    // MARK: - Main Body Detection
    
    /// Find the index where the main body text starts.
    /// Looks for the first sustained run of 3+ consecutive prose blocks.
    private static func findMainBodyStart(in blocks: [ClassifiedBlock]) -> Int {
        var consecutiveProse = 0
        
        for (index, block) in blocks.enumerated() {
            if block.kind == .bodyText {
                consecutiveProse += 1
                if consecutiveProse >= 3 {
                    // Body starts at the beginning of this run
                    return index - 2
                }
            } else if block.kind == .chapterHeading {
                // Headings don't break a prose run — they introduce it
                continue
            } else {
                consecutiveProse = 0
            }
        }
        
        return 0  // If no sustained run, treat everything as body
    }
}
