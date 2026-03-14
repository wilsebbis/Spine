import Foundation
import SwiftData

// MARK: - Source Type

/// Where the book was imported from. Extensible for future sources
/// (e.g., user-uploaded, library sync, store purchase).
enum BookSourceType: String, Codable, CaseIterable, Sendable {
    case gutenberg
    case local
    case physical
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
    
    // MARK: Reading Intent (Layer A)
    var readingIntentRaw: String?
    
    // MARK: Queue
    var isUpNext: Bool
    
    // MARK: Download
    var downloadURL: String?
    var isDownloaded: Bool
    
    // MARK: Audiobook
    var librivoxId: String?
    var hasAudiobook: Bool
    var audiobookDurationSeconds: Int?
    
    // MARK: Physical Book Tracking
    var totalPhysicalChapters: Int
    var physicalCurrentChapter: Int
    var userRating: Int?           // 1-5 stars
    var userNotes: String?
    var physicalChapterTimesJSON: String?     // JSON: {"1": 12.5, "2": 8.3} — minutes per chapter
    var physicalSkippedChaptersJSON: String?  // JSON: [1, 2] — skipped chapter numbers
    
    // MARK: Custom Cover (Physical Books)
    var coverColorHex: String?   // e.g. "#2C3E50" for custom color cover
    var coverEmoji: String?      // e.g. "📚" displayed on custom cover
    var coverGlyph: String?      // SF Symbol name e.g. "bolt.fill" displayed on cover
    
    /// Per-chapter reading times in minutes.
    var physicalChapterTimes: [Int: Double] {
        get {
            guard let json = physicalChapterTimesJSON,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return dict.reduce(into: [:]) { result, pair in
                if let key = Int(pair.key) { result[key] = pair.value }
            }
        }
        set {
            let stringDict = newValue.reduce(into: [String: Double]()) { $0[String($1.key)] = $1.value }
            if let data = try? JSONEncoder().encode(stringDict) {
                physicalChapterTimesJSON = String(data: data, encoding: .utf8)
            }
        }
    }
    
    /// Set of chapters that were skipped (no XP/streak).
    var physicalSkippedChapters: Set<Int> {
        get {
            guard let json = physicalSkippedChaptersJSON,
                  let data = json.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([Int].self, from: data)
            else { return [] }
            return Set(arr)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue).sorted()) {
                physicalSkippedChaptersJSON = String(data: data, encoding: .utf8)
            }
        }
    }
    
    // MARK: Intelligence
    @Attribute(.externalStorage) var characterGraphJSON: String?  // Legacy, kept for migration
    
    @Relationship(deleteRule: .cascade, inverse: \BookIntelligence.book)
    var intelligence: BookIntelligence?
    
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
    
    @Relationship(deleteRule: .cascade, inverse: \AudiobookChapter.book)
    var audiobookChapters: [AudiobookChapter] = []
    
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
    
    var sortedAudioChapters: [AudiobookChapter] {
        audiobookChapters.sorted { $0.ordinal < $1.ordinal }
    }
    
    var audiobookProgress: Double {
        guard !audiobookChapters.isEmpty else { return 0 }
        let listened = audiobookChapters.filter { $0.isListened }.count
        return Double(listened) / Double(audiobookChapters.count)
    }
    
    var isPhysicalBook: Bool {
        sourceType == .physical
    }
    
    var physicalProgress: Double {
        guard totalPhysicalChapters > 0 else { return 0 }
        return Double(physicalCurrentChapter) / Double(totalPhysicalChapters)
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
        self.isUpNext = false
        self.isDownloaded = false
        self.hasAudiobook = false
        self.totalPhysicalChapters = 0
        self.physicalCurrentChapter = 0
        self.downloadURL = gutenbergId.map { "https://www.gutenberg.org/ebooks/\($0).epub3.images" }
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Convenience init for physical books.
    convenience init(
        title: String,
        author: String,
        totalChapters: Int,
        bookDescription: String = "",
        coverImageData: Data? = nil,
        coverColorHex: String? = nil,
        coverEmoji: String? = nil,
        coverGlyph: String? = nil
    ) {
        self.init(
            title: title,
            author: author,
            bookDescription: bookDescription,
            coverImageData: coverImageData,
            sourceType: .physical
        )
        self.totalPhysicalChapters = totalChapters
        self.isDownloaded = true  // Physical books are always "available"
        self.importStatus = .completed
        self.coverColorHex = coverColorHex
        self.coverEmoji = coverEmoji
        self.coverGlyph = coverGlyph
    }
    
    /// Gutenberg EPUB3 download URL derived from gutenbergId
    var gutenbergDownloadURL: URL? {
        if let downloadURL, let url = URL(string: downloadURL) {
            return url
        }
        guard let gid = gutenbergId else { return nil }
        return URL(string: "https://www.gutenberg.org/ebooks/\(gid).epub3.images")
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
