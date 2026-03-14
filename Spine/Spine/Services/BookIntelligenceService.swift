import Foundation
import NaturalLanguage
import SwiftData
import FoundationModels
import os.log

// MARK: - Book Intelligence Service
// Two-pass pipeline that precomputes all NLP at import time so the reader never does heavy work.
//
// Pass A (import-time, synchronous):
//   • NLTagger NER → characters, places, organizations
//   • EmbeddingService → chunk vectors
//   • Cost: ~1-3s for typical novel
//
// Pass B (background, async):
//   • FoundationModels → per-unit summaries, chapter summaries, arc summaries
//   • Cost: ~10-60s depending on book size, runs in background
//
// Incremental: when user marks units as read, only process new units.

@MainActor
final class BookIntelligenceService {
    
    private let logger = Logger(subsystem: "com.spine.app", category: "intelligence")
    private let embeddingService = EmbeddingService()
    
    // MARK: - Pass A: NER + Embeddings (synchronous, import-time)
    
    /// Run at import time. Extracts all entities and builds embedding index.
    /// Typically completes in 1-3 seconds.
    func runPassA(book: Book, intelligence: BookIntelligence, modelContext: ModelContext) {
        logger.info("🧠 Pass A starting for '\(book.title)'")
        let startTime = Date()
        
        let units = book.sortedUnits
        let tagger = NLTagger(tagSchemes: [.nameType])
        var entityMap: [String: CachedEntity] = [:]
        
        for unit in units {
            tagger.string = unit.plainText
            let range = unit.plainText.startIndex..<unit.plainText.endIndex
            
            tagger.enumerateTags(
                in: range,
                unit: .word,
                scheme: .nameType,
                options: [.omitPunctuation, .omitWhitespace, .joinNames]
            ) { tag, tokenRange in
                guard let tag else { return true }
                
                let entityType: CachedEntityType?
                switch tag {
                case .personalName: entityType = .person
                case .placeName: entityType = .place
                case .organizationName: entityType = .organization
                default: entityType = nil
                }
                
                if let entityType {
                    let name = String(unit.plainText[tokenRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .capitalized
                    guard name.count >= 2 else { return true }
                    
                    let key = "\(entityType.rawValue)-\(name)"
                    if var existing = entityMap[key] {
                        existing.mentionCount += 1
                        if !existing.unitAppearances.contains(unit.ordinal) {
                            existing.unitAppearances.append(unit.ordinal)
                        }
                        entityMap[key] = existing
                    } else {
                        let context = extractSentence(
                            containing: tokenRange,
                            in: unit.plainText
                        )
                        entityMap[key] = CachedEntity(
                            name: name,
                            type: entityType,
                            mentionCount: 1,
                            firstAppearanceUnit: unit.ordinal,
                            firstContext: context,
                            unitAppearances: [unit.ordinal]
                        )
                    }
                }
                return true
            }
        }
        
        // Serialize entities
        let entities = entityMap.values.sorted { $0.mentionCount > $1.mentionCount }
        if let data = try? JSONEncoder().encode(entities),
           let json = String(data: data, encoding: .utf8) {
            intelligence.entitiesJSON = json
        }
        
        intelligence.lastProcessedUnit = units.last?.ordinal ?? -1
        intelligence.passACompleted = true
        intelligence.updatedAt = Date()
        
        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("🧠 Pass A complete: \(entities.count) entities in \(String(format: "%.1f", elapsed))s")
    }
    
    // MARK: - Pass B: AI Summaries (async, background)
    
    /// Run in background after import. Generates AI summaries per unit/chapter/arc.
    /// Can be called incrementally (only processes units after lastProcessedUnit).
    nonisolated func runPassB(
        bookID: UUID,
        modelContainerConfig: ModelConfiguration
    ) {
        Task.detached(priority: .utility) {
            let logger = Logger(subsystem: "com.spine.app", category: "intelligence")
            logger.info("🧠 Pass B starting for book \(bookID)")
            
            guard FoundationModelService.isAvailable else {
                logger.info("🧠 Pass B skipped — FoundationModels not available")
                return
            }
            
            // Create a fresh ModelContainer for this background task
            do {
                let container = try ModelContainer(for: Book.self, BookIntelligence.self,
                                                    configurations: modelContainerConfig)
                let context = ModelContext(container)
                
                // Fetch book and intelligence
                let descriptor = FetchDescriptor<BookIntelligence>(
                    predicate: #Predicate { $0.book?.id == bookID }
                )
                guard let intelligence = try context.fetch(descriptor).first,
                      let book = intelligence.book else {
                    logger.warning("🧠 Pass B: Book or intelligence not found")
                    return
                }
                
                let units = book.sortedUnits
                let startAfter = intelligence.lastProcessedUnit
                let unitsToProcess = units.filter { $0.ordinal > startAfter }
                
                guard !unitsToProcess.isEmpty else {
                    logger.info("🧠 Pass B: No new units to process")
                    intelligence.passBCompleted = true
                    try context.save()
                    return
                }
                
                // Load existing summaries
                var summaries = Self.loadSummaries(from: intelligence)
                
                // Generate unit summaries
                for unit in unitsToProcess {
                    if summaries.unitSummaries[unit.ordinal] == nil {
                        if let summary = await Self.summarize(
                            text: unit.plainText,
                            bookTitle: book.title,
                            prompt: "Summarize this reading unit in 2 sentences. Key events and character actions only. No markdown."
                        ) {
                            summaries.unitSummaries[unit.ordinal] = summary
                        }
                    }
                }
                
                // Generate chapter summaries from unit summaries
                for unit in unitsToProcess {
                    if summaries.chapterSummaries[unit.ordinal] == nil,
                       let unitSummary = summaries.unitSummaries[unit.ordinal] {
                        if let chapterSummary = await Self.summarize(
                            text: unitSummary,
                            bookTitle: book.title,
                            prompt: "Rewrite as a one-sentence chapter recap. No markdown."
                        ) {
                            summaries.chapterSummaries[unit.ordinal] = chapterSummary
                        }
                    }
                }
                
                // Generate arc summaries every 3 units
                let maxOrdinal = units.last?.ordinal ?? 0
                let arcSize = 3
                var arcStart = 0
                while arcStart + arcSize - 1 <= maxOrdinal {
                    let arcEnd = arcStart + arcSize - 1
                    if summaries.arcSummaries[arcStart] == nil {
                        let combined = (arcStart...arcEnd)
                            .compactMap { summaries.chapterSummaries[$0] }
                        if !combined.isEmpty {
                            if let arc = await Self.summarize(
                                text: combined.joined(separator: " "),
                                bookTitle: book.title,
                                prompt: "Synthesize into one paragraph capturing the story arc. No markdown."
                            ) {
                                summaries.arcSummaries[arcStart] = arc
                            }
                        }
                    }
                    arcStart += arcSize
                }
                
                // Persist
                Self.saveSummaries(summaries, to: intelligence)
                intelligence.lastProcessedUnit = maxOrdinal
                intelligence.passBCompleted = true
                intelligence.updatedAt = Date()
                
                try context.save()
                logger.info("🧠 Pass B complete: \(summaries.unitSummaries.count) unit summaries, \(summaries.chapterSummaries.count) chapter summaries, \(summaries.arcSummaries.count) arc summaries")
                
            } catch {
                logger.error("🧠 Pass B failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Incremental Update
    
    /// Called after user completes a unit. Processes only the new unit's entities.
    func processIncrementalUnit(
        _ unit: ReadingUnit,
        book: Book,
        intelligence: BookIntelligence
    ) {
        // Update entities with new unit's NER
        var entities = Self.loadEntities(from: intelligence)
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = unit.plainText
        let range = unit.plainText.startIndex..<unit.plainText.endIndex
        
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            guard let tag else { return true }
            
            let entityType: CachedEntityType?
            switch tag {
            case .personalName: entityType = .person
            case .placeName: entityType = .place
            case .organizationName: entityType = .organization
            default: entityType = nil
            }
            
            if let entityType {
                let name = String(unit.plainText[tokenRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .capitalized
                guard name.count >= 2 else { return true }
                
                if let idx = entities.firstIndex(where: { $0.name == name && $0.type == entityType }) {
                    entities[idx].mentionCount += 1
                    if !entities[idx].unitAppearances.contains(unit.ordinal) {
                        entities[idx].unitAppearances.append(unit.ordinal)
                    }
                } else {
                    let context = extractSentence(containing: tokenRange, in: unit.plainText)
                    entities.append(CachedEntity(
                        name: name,
                        type: entityType,
                        mentionCount: 1,
                        firstAppearanceUnit: unit.ordinal,
                        firstContext: context,
                        unitAppearances: [unit.ordinal]
                    ))
                }
            }
            return true
        }
        
        // Re-sort and persist
        entities.sort { $0.mentionCount > $1.mentionCount }
        if let data = try? JSONEncoder().encode(entities),
           let json = String(data: data, encoding: .utf8) {
            intelligence.entitiesJSON = json
        }
        intelligence.updatedAt = Date()
        
        logger.info("🧠 Incremental: processed unit \(unit.ordinal), \(entities.count) total entities")
    }
    
    // MARK: - Cache Read Helpers (used by CodexView and background tasks)
    // These are nonisolated so they can be called from detached background tasks.
    
    nonisolated static func loadEntities(from intelligence: BookIntelligence) -> [CachedEntity] {
        guard let json = intelligence.entitiesJSON,
              let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CachedEntity].self, from: data)) ?? []
    }
    
    nonisolated static func loadSummaries(from intelligence: BookIntelligence) -> CachedSummaries {
        var result = CachedSummaries()
        
        if let json = intelligence.unitSummariesJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            result.unitSummaries = decoded.reduce(into: [:]) { dict, pair in
                if let key = Int(pair.key) { dict[key] = pair.value }
            }
        }
        if let json = intelligence.chapterSummariesJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            result.chapterSummaries = decoded.reduce(into: [:]) { dict, pair in
                if let key = Int(pair.key) { dict[key] = pair.value }
            }
        }
        if let json = intelligence.arcSummariesJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            result.arcSummaries = decoded.reduce(into: [:]) { dict, pair in
                if let key = Int(pair.key) { dict[key] = pair.value }
            }
        }
        
        return result
    }
    
    nonisolated static func saveSummaries(_ summaries: CachedSummaries, to intelligence: BookIntelligence) {
        let encoder = JSONEncoder()
        
        let unitDict = summaries.unitSummaries.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value }
        if let data = try? encoder.encode(unitDict) {
            intelligence.unitSummariesJSON = String(data: data, encoding: .utf8)
        }
        
        let chapterDict = summaries.chapterSummaries.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value }
        if let data = try? encoder.encode(chapterDict) {
            intelligence.chapterSummariesJSON = String(data: data, encoding: .utf8)
        }
        
        let arcDict = summaries.arcSummaries.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value }
        if let data = try? encoder.encode(arcDict) {
            intelligence.arcSummariesJSON = String(data: data, encoding: .utf8)
        }
    }
    
    // MARK: - Content Hash
    
    static func computeContentHash(for book: Book) -> String {
        let text = book.sortedUnits.map { $0.plainText }.joined()
        let data = Data(text.utf8)
        // Simple hash — not cryptographic, just for change detection
        var hash: UInt64 = 5381
        for byte in data.prefix(10000) {  // First 10KB is enough for change detection
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
    
    // MARK: - Private Helpers
    
    private func extractSentence(
        containing range: Range<String.Index>,
        in text: String
    ) -> String {
        let searchStart = text.index(range.lowerBound, offsetBy: -100, limitedBy: text.startIndex) ?? text.startIndex
        let searchEnd = text.index(range.upperBound, offsetBy: 100, limitedBy: text.endIndex) ?? text.endIndex
        
        let snippet = String(text[searchStart..<searchEnd])
        let entityText = String(text[range])
        let sentences = snippet.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        if let match = sentences.first(where: { $0.contains(entityText) }) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func summarize(text: String, bookTitle: String, prompt: String) async -> String? {
        guard FoundationModelService.isAvailable else { return nil }
        do {
            let session = LanguageModelSession()
            let words = text.split(separator: " ")
            let truncated = words.prefix(1500).joined(separator: " ")
            let fullPrompt = "From \"\(bookTitle)\":\n\n\(truncated)\n\n\(prompt)"
            let response = try await session.respond(to: fullPrompt)
            return response.content
        } catch {
            return nil
        }
    }
}
