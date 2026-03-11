import Foundation

// MARK: - Segmentation Engine
// Converts parsed chapters into daily reading units (~2000-2500 words each).
// Uses deterministic heuristics for splitting: paragraph boundaries, headings,
// horizontal rules, dialogue transitions, and scene breaks.

struct SegmentationEngine: Sendable {
    
    /// Target word count range for a single reading unit.
    struct Config: Sendable {
        let minWords: Int
        let maxWords: Int
        let targetWords: Int
        let wordsPerMinute: Int
        
        static let `default` = Config(
            minWords: 1500,
            maxWords: 3000,
            targetWords: 2250,
            wordsPerMinute: 225
        )
    }
    
    private let config: Config
    
    init(config: Config = .default) {
        self.config = config
    }
    
    // MARK: - Public API
    
    /// Segment parsed chapters into reading units.
    /// Returns an array of SegmentedUnit structs ready for persistence.
    func segment(chapters: [ParsedChapter]) -> [SegmentedUnit] {
        var units: [SegmentedUnit] = []
        var globalOrdinal = 0
        
        for chapter in chapters {
            let chapterUnits = segmentChapter(chapter, startingOrdinal: globalOrdinal)
            units.append(contentsOf: chapterUnits)
            globalOrdinal += chapterUnits.count
        }
        
        return units
    }
    
    // MARK: - Chapter Segmentation
    
    private func segmentChapter(_ chapter: ParsedChapter, startingOrdinal: Int) -> [SegmentedUnit] {
        // If chapter is within acceptable range, use it as a single unit
        if chapter.wordCount <= config.maxWords && chapter.wordCount >= config.minWords {
            return [SegmentedUnit(
                ordinal: startingOrdinal,
                title: chapter.title,
                plainText: chapter.plainText,
                htmlContent: chapter.htmlContent,
                wordCount: chapter.wordCount,
                estimatedMinutes: Double(chapter.wordCount) / Double(config.wordsPerMinute),
                startCharOffset: 0,
                endCharOffset: chapter.plainText.count,
                chapterOrdinal: chapter.ordinal
            )]
        }
        
        // If chapter is small, still make it a unit (don't merge with other chapters)
        if chapter.wordCount < config.minWords {
            return [SegmentedUnit(
                ordinal: startingOrdinal,
                title: chapter.title,
                plainText: chapter.plainText,
                htmlContent: chapter.htmlContent,
                wordCount: chapter.wordCount,
                estimatedMinutes: Double(chapter.wordCount) / Double(config.wordsPerMinute),
                startCharOffset: 0,
                endCharOffset: chapter.plainText.count,
                chapterOrdinal: chapter.ordinal
            )]
        }
        
        // Chapter is too long — split into multiple units
        return splitLongChapter(chapter, startingOrdinal: startingOrdinal)
    }
    
    // MARK: - Long Chapter Splitting
    
    private func splitLongChapter(_ chapter: ParsedChapter, startingOrdinal: Int) -> [SegmentedUnit] {
        let paragraphs = splitIntoParagraphs(chapter.plainText)
        var units: [SegmentedUnit] = []
        var currentParagraphs: [ParagraphInfo] = []
        var currentWordCount = 0
        var unitIndex = 0
        
        for paragraph in paragraphs {
            currentParagraphs.append(paragraph)
            currentWordCount += paragraph.wordCount
            
            // Check if we should split here
            if currentWordCount >= config.targetWords {
                // Look for a good split point near the target
                let splitPoint = findBestSplitPoint(
                    paragraphs: currentParagraphs,
                    currentWordCount: currentWordCount
                )
                
                if let splitPoint, splitPoint > 0 {
                    // Split at the found point
                    let unitParagraphs = Array(currentParagraphs[0..<splitPoint])
                    let remainingParagraphs = Array(currentParagraphs[splitPoint...])
                    
                    let unit = createUnit(
                        from: unitParagraphs,
                        chapter: chapter,
                        ordinal: startingOrdinal + unitIndex,
                        unitIndex: unitIndex
                    )
                    units.append(unit)
                    unitIndex += 1
                    
                    currentParagraphs = remainingParagraphs
                    currentWordCount = remainingParagraphs.reduce(0) { $0 + $1.wordCount }
                } else if currentWordCount >= config.maxWords {
                    // Force split at paragraph boundary
                    let unit = createUnit(
                        from: currentParagraphs,
                        chapter: chapter,
                        ordinal: startingOrdinal + unitIndex,
                        unitIndex: unitIndex
                    )
                    units.append(unit)
                    unitIndex += 1
                    
                    currentParagraphs = []
                    currentWordCount = 0
                }
            }
        }
        
        // Add remaining paragraphs as final unit
        if !currentParagraphs.isEmpty {
            let unit = createUnit(
                from: currentParagraphs,
                chapter: chapter,
                ordinal: startingOrdinal + unitIndex,
                unitIndex: unitIndex
            )
            units.append(unit)
        }
        
        return units
    }
    
    // MARK: - Paragraph Analysis
    
    private struct ParagraphInfo: Sendable {
        let text: String
        let wordCount: Int
        let charStart: Int
        let charEnd: Int
        let isBreakCandidate: Bool
    }
    
    private func splitIntoParagraphs(_ text: String) -> [ParagraphInfo] {
        let lines = text.components(separatedBy: "\n\n")
        var paragraphs: [ParagraphInfo] = []
        var charOffset = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                charOffset += line.count + 2 // account for \n\n
                continue
            }
            
            let wc = trimmed.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count
            
            let isBreak = isBreakCandidate(trimmed)
            
            paragraphs.append(ParagraphInfo(
                text: trimmed,
                wordCount: wc,
                charStart: charOffset,
                charEnd: charOffset + line.count,
                isBreakCandidate: isBreak
            ))
            
            charOffset += line.count + 2
        }
        
        return paragraphs
    }
    
    /// Detect natural break points for segmentation.
    private func isBreakCandidate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Horizontal rules / separators
        if trimmed.allSatisfy({ $0 == "*" || $0 == "-" || $0 == "_" || $0 == " " }) && trimmed.count >= 3 {
            return true
        }
        
        // Scene break markers
        let sceneBreaks = ["* * *", "***", "---", "⁂", "§", "• • •"]
        if sceneBreaks.contains(trimmed) { return true }
        
        // Short lines that look like headings (all caps, or very short)
        if trimmed.count < 60 && trimmed == trimmed.uppercased() && trimmed.count > 2 {
            return true
        }
        
        // Lines starting with "Chapter", "CHAPTER", "Part", "PART", "Book", "BOOK"
        let headingPrefixes = ["chapter", "part", "book", "act", "scene", "letter", "section"]
        let lowered = trimmed.lowercased()
        for prefix in headingPrefixes {
            if lowered.hasPrefix(prefix) { return true }
        }
        
        // Date-like lines (epistolary text detection)
        let datePatterns = [
            #"^\d{1,2}\s+(January|February|March|April|May|June|July|August|September|October|November|December)"#,
            #"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}"#,
            #"^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)"#,
        ]
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Split Point Selection
    
    /// Find the best paragraph index to split at, given we've accumulated enough words.
    private func findBestSplitPoint(
        paragraphs: [ParagraphInfo],
        currentWordCount: Int
    ) -> Int? {
        // Look for break candidates near the end of the current accumulation
        // Prefer splitting at natural break points within the last ~30% of content
        let searchStart = max(0, paragraphs.count * 2 / 3)
        
        // First pass: look for explicit break candidates
        for i in stride(from: paragraphs.count - 1, through: searchStart, by: -1) {
            if paragraphs[i].isBreakCandidate {
                return i
            }
        }
        
        // Second pass: look for dialogue transitions (paragraph ending in closing quote)
        for i in stride(from: paragraphs.count - 1, through: searchStart, by: -1) {
            let text = paragraphs[i].text
            if text.hasSuffix("\"") || text.hasSuffix("'") || text.hasSuffix("\u{201D}") {
                // Check if next paragraph starts differently (speaker change)
                if i + 1 < paragraphs.count {
                    let next = paragraphs[i + 1].text
                    if !next.hasPrefix("\"") && !next.hasPrefix("\u{201C}") {
                        return i + 1
                    }
                }
            }
        }
        
        // Third pass: look for paragraph ending with a period (sentence boundary)
        for i in stride(from: paragraphs.count - 1, through: searchStart, by: -1) {
            let text = paragraphs[i].text
            if text.hasSuffix(".") || text.hasSuffix("?") || text.hasSuffix("!") {
                return i + 1
            }
        }
        
        // Fallback: split at the last paragraph
        return paragraphs.count
    }
    
    // MARK: - Unit Construction
    
    private func createUnit(
        from paragraphs: [ParagraphInfo],
        chapter: ParsedChapter,
        ordinal: Int,
        unitIndex: Int
    ) -> SegmentedUnit {
        let text = paragraphs.map(\.text).joined(separator: "\n\n")
        let wc = paragraphs.reduce(0) { $0 + $1.wordCount }
        let startOffset = paragraphs.first?.charStart ?? 0
        let endOffset = paragraphs.last?.charEnd ?? text.count
        
        // Build title
        let unitTitle: String
        if unitIndex == 0 {
            unitTitle = chapter.title
        } else {
            unitTitle = "\(chapter.title) — Part \(unitIndex + 1)"
        }
        
        // Build simple HTML wrapping
        let htmlContent = paragraphs.map { "<p>\($0.text)</p>" }.joined(separator: "\n")
        
        return SegmentedUnit(
            ordinal: ordinal,
            title: unitTitle,
            plainText: text,
            htmlContent: htmlContent,
            wordCount: wc,
            estimatedMinutes: Double(wc) / Double(config.wordsPerMinute),
            startCharOffset: startOffset,
            endCharOffset: endOffset,
            chapterOrdinal: chapter.ordinal
        )
    }
}

// MARK: - Segmented Unit Output

/// The output of the segmentation engine, ready for SwiftData persistence.
struct SegmentedUnit: Sendable {
    let ordinal: Int
    let title: String
    let plainText: String
    let htmlContent: String
    let wordCount: Int
    let estimatedMinutes: Double
    let startCharOffset: Int
    let endCharOffset: Int
    let chapterOrdinal: Int
}
