import Foundation
import SwiftData

// MARK: - Book Intelligence
// Precomputed sidecar for book NLP data.
// Generated at import time (Pass A: NER + embeddings) and in background (Pass B: AI summaries).
// CodexView reads from these cached fields — never recomputes on the reading path.

@Model
final class BookIntelligence {
    @Attribute(.unique) var id: UUID
    
    // MARK: - Pipeline Metadata
    var pipelineVersion: Int          // Bump to invalidate + re-process
    var lastProcessedUnit: Int        // For incremental updates
    var contentHash: String           // SHA256 of book text — detect changes
    var passACompleted: Bool          // NER + embeddings done
    var passBCompleted: Bool          // AI summaries done
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Cached Intelligence (JSON blobs, external storage for large books)
    
    /// NER entities: [{name, type, mentionCount, firstAppearanceUnit, firstContext, unitAppearances}]
    @Attribute(.externalStorage) var entitiesJSON: String?
    
    /// Per-unit 2-sentence summaries: {ordinal: "summary"}
    @Attribute(.externalStorage) var unitSummariesJSON: String?
    
    /// Per-chapter 1-sentence recaps: {ordinal: "summary"}
    @Attribute(.externalStorage) var chapterSummariesJSON: String?
    
    /// Arc summaries every 3 units: {startOrdinal: "paragraph"}
    @Attribute(.externalStorage) var arcSummariesJSON: String?
    
    /// Pre-built story recap (full ReadingRecap JSON) per progress checkpoint
    /// Format: {unitOrdinal: ReadingRecapJSON}
    @Attribute(.externalStorage) var storyRecapCacheJSON: String?
    
    /// Character overview cache (CharacterRefresher JSON)
    @Attribute(.externalStorage) var characterCacheJSON: String?
    
    // MARK: - Relationship
    @Relationship var book: Book?
    
    // MARK: - Init
    
    init(book: Book, contentHash: String) {
        self.id = UUID()
        self.pipelineVersion = Self.currentPipelineVersion
        self.lastProcessedUnit = -1
        self.contentHash = contentHash
        self.passACompleted = false
        self.passBCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.book = book
    }
    
    // MARK: - Version
    
    static let currentPipelineVersion = 1
    
    var needsReprocessing: Bool {
        pipelineVersion < Self.currentPipelineVersion
    }
}

// MARK: - Codable Entity (stored in entitiesJSON)

struct CachedEntity: Codable, Identifiable, Sendable {
    var id: String { "\(type.rawValue)-\(name)" }
    let name: String
    let type: CachedEntityType
    var mentionCount: Int
    var firstAppearanceUnit: Int
    var firstContext: String
    var unitAppearances: [Int]
}

enum CachedEntityType: String, Codable, Sendable {
    case person
    case place
    case organization
}

// MARK: - Codable Summary Cache

struct CachedSummaries: Codable, Sendable {
    var unitSummaries: [Int: String] = [:]
    var chapterSummaries: [Int: String] = [:]
    var arcSummaries: [Int: String] = [:]
}
