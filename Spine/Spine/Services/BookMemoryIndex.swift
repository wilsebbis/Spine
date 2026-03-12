import Foundation
import NaturalLanguage
import os.log

// MARK: - Book Memory Index
// Multi-layer book memory for hierarchical retrieval.
// Five abstraction levels: chunks, scenes, unit summaries, chapter summaries, arc summaries.
// Each entry carries embedding, entity mentions, event density, and adjacency info.

final class BookMemoryIndex: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.spine.app", category: "memory")
    private let embeddingService = EmbeddingService()
    
    // MARK: - Memory Entry
    
    struct MemoryEntry: Sendable, Identifiable {
        let id: String
        let text: String
        let embedding: [Double]
        let unitOrdinal: Int
        let tier: Tier
        let entityMentions: Set<String>
        let eventDensity: Double
        let sourceRange: ClosedRange<Int>  // start..end unit ordinals
        var adjacentEntryIDs: [String]     // for neighbor expansion
        
        enum Tier: Int, Sendable, Comparable {
            case chunk = 0
            case scene = 1
            case unitSummary = 2
            case chapterSummary = 3
            case arcSummary = 4
            
            static func < (lhs: Tier, rhs: Tier) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
            
            var label: String {
                switch self {
                case .chunk: return "Passage"
                case .scene: return "Scene"
                case .unitSummary: return "Unit Summary"
                case .chapterSummary: return "Chapter Summary"
                case .arcSummary: return "Arc Summary"
                }
            }
        }
    }
    
    // MARK: - Entity Index
    
    struct EntityEntry: Sendable {
        let name: String
        let type: String
        var unitOrdinals: Set<Int>
        var totalMentions: Int
    }
    
    // MARK: - State
    
    private(set) var entries: [MemoryEntry] = []
    private(set) var entityIndex: [String: EntityEntry] = [:]
    private(set) var unitSummaries: [Int: String] = [:]
    private(set) var chapterSummaries: [Int: String] = [:]
    private(set) var arcSummaries: [Int: String] = [:]
    private(set) var isBuilt = false
    
    // MARK: - Build Index (Chunks + Scenes + Entities)
    
    func buildIndex(
        from book: Book,
        upToUnit currentOrdinal: Int,
        chunkSize: Int = 300,
        overlapSize: Int = 50
    ) {
        let readUnits = book.sortedUnits.filter { $0.ordinal <= currentOrdinal }
        var allEntries: [MemoryEntry] = []
        var entryCounter = 0
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        
        for unit in readUnits {
            let text = unit.plainText
            var unitChunkIDs: [String] = []
            
            // --- Chunks ---
            let words = text.split(separator: " ")
            var i = 0
            while i < words.count {
                let end = min(i + chunkSize, words.count)
                let chunkText = words[i..<end].joined(separator: " ")
                let entities = extractEntityNames(from: chunkText, tagger: tagger)
                let density = computeEventDensity(chunkText)
                let embedding = embeddingService.embed(text: chunkText) ?? []
                
                let entryID = "chunk-\(unit.ordinal)-\(entryCounter)"
                entryCounter += 1
                
                allEntries.append(MemoryEntry(
                    id: entryID,
                    text: chunkText,
                    embedding: embedding,
                    unitOrdinal: unit.ordinal,
                    tier: .chunk,
                    entityMentions: entities,
                    eventDensity: density,
                    sourceRange: unit.ordinal...unit.ordinal,
                    adjacentEntryIDs: []
                ))
                unitChunkIDs.append(entryID)
                i += chunkSize - overlapSize
            }
            
            // Link adjacent chunks
            for j in 0..<unitChunkIDs.count {
                let idx = allEntries.count - unitChunkIDs.count + j
                var neighbors: [String] = []
                if j > 0 { neighbors.append(unitChunkIDs[j - 1]) }
                if j < unitChunkIDs.count - 1 { neighbors.append(unitChunkIDs[j + 1]) }
                allEntries[idx].adjacentEntryIDs = neighbors
            }
            
            // --- Scenes (paragraph-level) ---
            let paragraphs = text.components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            for paragraph in paragraphs {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count > 50 else { continue }
                
                let entities = extractEntityNames(from: trimmed, tagger: tagger)
                let density = computeEventDensity(trimmed)
                let embedding = embeddingService.embed(text: trimmed) ?? []
                
                let entryID = "scene-\(unit.ordinal)-\(entryCounter)"
                entryCounter += 1
                
                allEntries.append(MemoryEntry(
                    id: entryID,
                    text: trimmed,
                    embedding: embedding,
                    unitOrdinal: unit.ordinal,
                    tier: .scene,
                    entityMentions: entities,
                    eventDensity: density,
                    sourceRange: unit.ordinal...unit.ordinal,
                    adjacentEntryIDs: []
                ))
            }
            
            // --- Entity side-index ---
            buildEntityIndex(from: text, unitOrdinal: unit.ordinal, tagger: tagger)
        }
        
        entries = allEntries
        isBuilt = true
        logger.info("📚 Index: \(allEntries.count) entries, \(self.entityIndex.count) entities from \(readUnits.count) units")
    }
    
    // MARK: - Inject Summaries
    
    func addUnitSummary(_ summary: String, forUnit ordinal: Int) {
        unitSummaries[ordinal] = summary
        addSummaryEntry(summary, ordinal: ordinal, tier: .unitSummary, range: ordinal...ordinal)
    }
    
    func addChapterSummary(_ summary: String, forUnit ordinal: Int) {
        chapterSummaries[ordinal] = summary
        addSummaryEntry(summary, ordinal: ordinal, tier: .chapterSummary, range: ordinal...ordinal)
    }
    
    func addArcSummary(_ summary: String, startUnit: Int, endUnit: Int) {
        arcSummaries[startUnit] = summary
        addSummaryEntry(summary, ordinal: endUnit, tier: .arcSummary, range: startUnit...endUnit)
    }
    
    private func addSummaryEntry(_ text: String, ordinal: Int, tier: MemoryEntry.Tier, range: ClosedRange<Int>) {
        let embedding = embeddingService.embed(text: text) ?? []
        let entities = extractEntityNames(from: text, tagger: NLTagger(tagSchemes: [.nameType]))
        
        entries.append(MemoryEntry(
            id: "\(tier)-\(ordinal)-\(entries.count)",
            text: text,
            embedding: embedding,
            unitOrdinal: ordinal,
            tier: tier,
            entityMentions: entities,
            eventDensity: 0.8,
            sourceRange: range,
            adjacentEntryIDs: []
        ))
    }
    
    // MARK: - Neighbor Expansion
    
    /// Get adjacent entries for a given entry ID.
    func neighbors(of entryID: String) -> [MemoryEntry] {
        guard let entry = entries.first(where: { $0.id == entryID }) else { return [] }
        return entry.adjacentEntryIDs.compactMap { id in
            entries.first { $0.id == id }
        }
    }
    
    // MARK: - Entity Index
    
    private func buildEntityIndex(from text: String, unitOrdinal: Int, tagger: NLTagger) {
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(
            in: range, unit: .word, scheme: .nameType,
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
                let name = String(text[tokenRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                guard name.count >= 2 else { return true }
                let key = name.lowercased()
                if var existing = entityIndex[key] {
                    existing.unitOrdinals.insert(unitOrdinal)
                    existing.totalMentions += 1
                    entityIndex[key] = existing
                } else {
                    entityIndex[key] = EntityEntry(
                        name: name, type: typeString,
                        unitOrdinals: [unitOrdinal], totalMentions: 1
                    )
                }
            }
            return true
        }
    }
    
    private func extractEntityNames(from text: String, tagger: NLTagger) -> Set<String> {
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        var names: Set<String> = []
        tagger.enumerateTags(
            in: range, unit: .word, scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                let name = String(text[tokenRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.count >= 2 else { return true }
                names.insert(name.lowercased())
            }
            return true
        }
        return names
    }
    
    // MARK: - Event Density
    
    private func computeEventDensity(_ text: String) -> Double {
        let markers = [
            "said", "told", "asked", "replied", "went", "came", "arrived",
            "left", "found", "discovered", "realized", "learned", "killed",
            "died", "married", "fought", "escaped", "suddenly", "finally"
        ]
        let words = text.lowercased().split(separator: " ")
        guard words.count > 10 else { return 0 }
        let count = words.filter { markers.contains(String($0).trimmingCharacters(in: .punctuationCharacters)) }.count
        return min(1.0, Double(count) / Double(words.count) * 10.0)
    }
    
    // MARK: - Query Helpers
    
    func extractQueryEntities(_ query: String) -> Set<String> {
        return extractEntityNames(from: query, tagger: NLTagger(tagSchemes: [.nameType]))
    }
    
    func entities(ofType type: String) -> [EntityEntry] {
        entityIndex.values.filter { $0.type == type }
            .sorted { $0.totalMentions > $1.totalMentions }
    }
}
