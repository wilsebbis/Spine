import Foundation
import SwiftData

// MARK: - Source Type

/// Where the book was imported from. Extensible for future sources
/// (e.g., user-uploaded, library sync, store purchase).
enum BookSourceType: String, Codable, CaseIterable, Sendable {
    case gutenberg
    case local
}

// MARK: - Book

/// The root domain object representing a single book in Spine.
/// All other models relate back to a Book — it is the anchor of the data graph.
@Model
final class Book {
    // MARK: Identity
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var bookDescription: String
    
    // MARK: Media
    @Attribute(.externalStorage) var coverImageData: Data?
    
    // MARK: Metadata
    var sourceType: BookSourceType
    var language: String
    var gutenbergId: String?
    
    // MARK: EPUB Asset Info
    var localFileURI: String?
    var tocJSON: String?
    var manifestJSON: String?
    var spineJSON: String?
    var importStatus: ImportStatus
    var importError: String?
    var rawMetadataJSON: String?
    
    // MARK: Recommendation Metadata
    var genres: [String]
    var vibes: [String]
    @Attribute(.externalStorage) var synopsisEmbedding: Data?
    var popularityScore: Double
    
    // MARK: Book Detail Enrichment
    var longDescription: String?
    var themes: [String]
    var publicationYear: Int?
    var literaryPeriod: String?
    var authorMetadataJSON: String?
    
    // MARK: Intelligence (Phase 3)
    @Attribute(.externalStorage) var characterGraphJSON: String?
    
    // MARK: Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: Relationships
    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingUnit.book)
    var readingUnits: [ReadingUnit] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.book)
    var readingProgress: ReadingProgress?
    
    @Relationship(deleteRule: .cascade, inverse: \Highlight.book)
    var highlights: [Highlight] = []
    
    @Relationship(deleteRule: .cascade, inverse: \DailySession.book)
    var dailySessions: [DailySession] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Reaction.book)
    var reactions: [Reaction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \QuoteSave.book)
    var quoteSaves: [QuoteSave] = []
    
    @Relationship(deleteRule: .cascade, inverse: \BookInteraction.book)
    var interactions: [BookInteraction] = []
    
    // MARK: Computed
    var sortedUnits: [ReadingUnit] {
        readingUnits.sorted { $0.ordinal < $1.ordinal }
    }
    
    var sortedChapters: [Chapter] {
        chapters.sorted { $0.ordinal < $1.ordinal }
    }
    
    var totalWordCount: Int {
        chapters.reduce(0) { $0 + $1.wordCount }
    }
    
    var unitCount: Int {
        readingUnits.count
    }
    
    var estimatedHours: Double {
        Double(totalWordCount) / 225.0 / 60.0
    }
    
    var authorMetadata: AuthorMetadata? {
        get {
            guard let json = authorMetadataJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AuthorMetadata.self, from: data)
        }
        set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value) else {
                authorMetadataJSON = nil
                return
            }
            authorMetadataJSON = String(data: data, encoding: .utf8)
        }
    }
    
    init(
        title: String,
        author: String,
        bookDescription: String = "",
        coverImageData: Data? = nil,
        sourceType: BookSourceType = .gutenberg,
        language: String = "en",
        gutenbergId: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.bookDescription = bookDescription
        self.coverImageData = coverImageData
        self.sourceType = sourceType
        self.language = language
        self.gutenbergId = gutenbergId
        self.importStatus = .pending
        self.genres = []
        self.vibes = []
        self.themes = []
        self.popularityScore = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Import Status

enum ImportStatus: String, Codable, Sendable {
    case pending
    case parsing
    case segmenting
    case completed
    case failed
}
