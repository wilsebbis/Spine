import Foundation
import FoundationModels

// MARK: - Reading Recap (@Generable)
// Structured output for Foundation Models guided generation.
// Compact schema to stay within 4096-token context window.

@Generable(description: "A spoiler-safe reading recap")
struct ReadingRecap {
    @Guide(description: "Key plot events, max 7")
    let majorEvents: [String]
    
    @Guide(description: "Where major characters stand")
    let characterUpdates: [CharacterUpdate]
    
    @Guide(description: "Unresolved plot threads")
    let unresolvedThreads: [String]
    
    @Guide(description: "Details the reader should remember")
    let importantDetailsToRemember: [String]
    
    @Guide(description: "One paragraph story recap")
    let recapParagraph: String
    
    @Guide(description: "Coverage note, e.g. Focused on Chapters 1-12")
    let coverageNote: String
}

@Generable(description: "Character state")
struct CharacterUpdate {
    @Guide(description: "Name")
    let name: String
    
    @Guide(description: "Current status, 1 sentence")
    let status: String
}

// MARK: - Quick Refresher

@Generable(description: "Quick refresher bullets")
struct QuickRefresher {
    @Guide(description: "5-7 recent event bullets")
    let bullets: [String]
}

// MARK: - Character Refresher

@Generable(description: "Major character statuses")
struct CharacterRefresher {
    @Guide(description: "Each major character's status")
    let characters: [CharacterUpdate]
}

// MARK: - Recap Mode

enum RecapMode {
    case quick
    case storySoFar
    case character(name: String? = nil)
}

// MARK: - Mode-Specific Retrieval Weights

struct RetrievalWeights: Sendable {
    let semantic: Double
    let recency: Double
    let proximity: Double
    let entity: Double
    let summaryTier: Double
    
    /// Quick: recency-heavy, summary-tier-heavy
    static let quick = RetrievalWeights(
        semantic: 0.10, recency: 0.35, proximity: 0.25, entity: 0.10, summaryTier: 0.20
    )
    
    /// Story so far: arc/chapter summary-heavy with diversity
    static let storySoFar = RetrievalWeights(
        semantic: 0.20, recency: 0.15, proximity: 0.10, entity: 0.10, summaryTier: 0.45
    )
    
    /// Character: entity-overlap-heavy
    static let character = RetrievalWeights(
        semantic: 0.15, recency: 0.10, proximity: 0.05, entity: 0.50, summaryTier: 0.20
    )
}
