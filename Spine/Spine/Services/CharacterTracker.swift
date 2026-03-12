import Foundation
import NaturalLanguage
import os.log

// MARK: - Character Tracker
// Extracts named entities from reading units using NLTagger.
// Builds a spoiler-safe character graph that only includes characters
// from content the user has already read.

struct CharacterTracker: Sendable {
    
    private let logger = Logger(subsystem: "com.spine.app", category: "characters")
    
    // MARK: - Character Info
    
    struct CharacterInfo: Codable, Identifiable, Sendable {
        var id: String { name }
        let name: String
        var mentionCount: Int
        var firstAppearanceUnit: Int
        var firstContext: String  // Sentence where they first appear
    }
    
    // MARK: - Extract Characters
    
    /// Extract characters from all units up to the given ordinal.
    func extractCharacters(
        from book: Book,
        upToUnit currentOrdinal: Int
    ) -> [CharacterInfo] {
        let readUnits = book.sortedUnits.filter { $0.ordinal <= currentOrdinal }
        var characterMap: [String: CharacterInfo] = [:]
        
        // Try to load cached data first
        if let cached = loadCached(from: book) {
            // Filter to only show characters from read content
            let filtered = cached.filter { $0.firstAppearanceUnit <= currentOrdinal }
            if !filtered.isEmpty {
                return filtered.sorted { $0.mentionCount > $1.mentionCount }
            }
        }
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        
        for unit in readUnits {
            tagger.string = unit.plainText
            let range = unit.plainText.startIndex..<unit.plainText.endIndex
            
            tagger.enumerateTags(
                in: range,
                unit: .word,
                scheme: .nameType,
                options: [.omitPunctuation, .omitWhitespace, .joinNames]
            ) { tag, tokenRange in
                if tag == .personalName {
                    let name = String(unit.plainText[tokenRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Skip very short names (likely false positives)
                    guard name.count >= 2 else { return true }
                    
                    let normalized = name.capitalized
                    
                    if var existing = characterMap[normalized] {
                        existing.mentionCount += 1
                        characterMap[normalized] = existing
                    } else {
                        // Get first-appearance context
                        let context = extractSentence(
                            containing: tokenRange,
                            in: unit.plainText
                        )
                        
                        characterMap[normalized] = CharacterInfo(
                            name: normalized,
                            mentionCount: 1,
                            firstAppearanceUnit: unit.ordinal,
                            firstContext: context
                        )
                    }
                }
                return true
            }
        }
        
        let characters = characterMap.values
            .sorted { $0.mentionCount > $1.mentionCount }
        
        logger.info("👥 Found \(characters.count) characters in \(readUnits.count) units")
        return Array(characters)
    }
    
    // MARK: - Extract Entities for X-Ray
    
    struct EntityInfo: Identifiable, Sendable {
        var id: String { "\(type)-\(name)" }
        let name: String
        let type: String  // "person", "place", "organization"
        let count: Int
    }
    
    /// Extract all named entities from a single unit (for X-Ray overlay).
    func extractEntities(from unit: ReadingUnit) -> [EntityInfo] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = unit.plainText
        let range = unit.plainText.startIndex..<unit.plainText.endIndex
        
        var entityMap: [String: (type: String, count: Int)] = [:]
        
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            guard let tag else { return true }
            
            let typeString: String?
            switch tag {
            case .personalName: typeString = "person"
            case .placeName: typeString = "place"
            case .organizationName: typeString = "organization"
            default: typeString = nil
            }
            
            if let typeString {
                let name = String(unit.plainText[tokenRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .capitalized
                guard name.count >= 2 else { return true }
                
                let key = "\(typeString)-\(name)"
                entityMap[key, default: (type: typeString, count: 0)].count += 1
            }
            return true
        }
        
        return entityMap.map { key, value in
            let name = String(key.split(separator: "-", maxSplits: 1).last ?? "")
            return EntityInfo(name: name, type: value.type, count: value.count)
        }
        .sorted { $0.count > $1.count }
    }
    
    // MARK: - Cache
    
    func saveToBook(_ book: Book, characters: [CharacterInfo]) {
        if let data = try? JSONEncoder().encode(characters),
           let json = String(data: data, encoding: .utf8) {
            book.characterGraphJSON = json
        }
    }
    
    private func loadCached(from book: Book) -> [CharacterInfo]? {
        guard let json = book.characterGraphJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([CharacterInfo].self, from: data)
    }
    
    // MARK: - Helpers
    
    private func extractSentence(
        containing range: Range<String.Index>,
        in text: String
    ) -> String {
        // Find sentence boundaries around the entity
        let searchStart = text.index(range.lowerBound, offsetBy: -100, limitedBy: text.startIndex) ?? text.startIndex
        let searchEnd = text.index(range.upperBound, offsetBy: 100, limitedBy: text.endIndex) ?? text.endIndex
        
        let snippet = String(text[searchStart..<searchEnd])
        
        // Try to find sentence boundaries
        let sentences = snippet.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let entityText = String(text[range])
        
        if let match = sentences.first(where: { $0.contains(entityText) }) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
