import Foundation
import SwiftData

/// Represents a parsed chapter from an EPUB.
/// Chapters map to the EPUB spine, and are further subdivided
/// into ReadingUnits for the daily reading engine.
@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var ordinal: Int
    var title: String
    var sourceHref: String
    
    /// Plain-text content, stripped of HTML. Used for word counting and segmentation.
    @Attribute(.externalStorage) var plainText: String
    
    /// Normalized HTML content. Retained for future rich rendering.
    @Attribute(.externalStorage) var htmlContent: String
    
    var wordCount: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingUnit.chapter)
    var readingUnits: [ReadingUnit] = []
    
    var sortedUnits: [ReadingUnit] {
        readingUnits.sorted { $0.ordinal < $1.ordinal }
    }
    
    init(
        book: Book? = nil,
        ordinal: Int,
        title: String,
        sourceHref: String = "",
        plainText: String,
        htmlContent: String,
        wordCount: Int
    ) {
        self.id = UUID()
        self.book = book
        self.ordinal = ordinal
        self.title = title
        self.sourceHref = sourceHref
        self.plainText = plainText
        self.htmlContent = htmlContent
        self.wordCount = wordCount
        self.createdAt = Date()
    }
}
