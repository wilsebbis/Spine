import Foundation
import FoundationModels

// MARK: - Book Retrieval Tools
// Compact tools for bounded follow-up retrieval within Foundation Models sessions.
// App controls first-pass retrieval; these are for model-driven supplemental queries.

// MARK: - Recent Chapter Summaries

struct RecentChapterSummariesTool: Tool {
    let memoryIndex: BookMemoryIndex
    
    let name: String = "getRecentChapterSummaries"
    let description: String = "Get recent chapter summaries"
    
    @Generable
    struct Arguments {
        @Guide(description: "Number of chapters, max 5")
        let count: Int
    }
    
    func call(arguments: Arguments) async throws -> String {
        let summaries = await MainActor.run { memoryIndex.chapterSummaries }
            .sorted { $0.key > $1.key }
            .prefix(min(arguments.count, 5))
        guard !summaries.isEmpty else { return "No summaries yet." }
        return summaries.map { "U\($0.key + 1): \($0.value)" }.joined(separator: "\n")
    }
}

// MARK: - Search Relevant Scenes

struct SearchRelevantScenesTool: Tool {
    let memoryIndex: BookMemoryIndex
    let embeddingService: EmbeddingService
    let currentUnitOrdinal: Int
    
    let name: String = "searchRelevantScenes"
    let description: String = "Search for relevant scenes"
    
    @Generable
    struct Arguments {
        @Guide(description: "Search query")
        let query: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        let unitOrdinal = currentUnitOrdinal
        let scored = await MainActor.run {
            let qEmbed = embeddingService.embed(text: arguments.query) ?? []
            guard !qEmbed.isEmpty else { return [(BookMemoryIndex.MemoryEntry, Double)]() }
            return memoryIndex.entries
                .filter { $0.tier == .scene && $0.unitOrdinal <= unitOrdinal }
                .map { ($0, embeddingService.cosineSimilarity(qEmbed, $0.embedding)) }
        }
        guard !scored.isEmpty else { return "Search unavailable." }
        
        let results = scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        
        guard !results.isEmpty else { return "No scenes found." }
        return results.map { "[U\($0.0.unitOrdinal + 1)] \($0.0.text.prefix(300))" }.joined(separator: "\n---\n")
    }
}

// MARK: - Character Arc

struct CharacterArcTool: Tool {
    let memoryIndex: BookMemoryIndex
    
    let name: String = "getCharacterArc"
    let description: String = "Get a character's arc"
    
    @Generable
    struct Arguments {
        @Guide(description: "Character name")
        let characterName: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        let key = arguments.characterName.lowercased()
        let entityIndex = await MainActor.run { memoryIndex.entityIndex }
        let match = entityIndex[key]
            ?? entityIndex.first { $0.key.contains(key) }?.value
        guard let entity = match else { return "Not found." }
        
        let units = entity.unitOrdinals.sorted().map { String($0 + 1) }.joined(separator: ",")
        return "\(entity.name): \(entity.totalMentions) mentions in units \(units)"
    }
}
