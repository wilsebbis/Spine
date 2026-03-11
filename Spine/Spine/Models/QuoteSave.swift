import Foundation
import SwiftData

/// A saved favorite quote from a reading unit.
/// Separate from Highlight to allow distinct curation
/// and future social sharing of quotes.
@Model
final class QuoteSave {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var readingUnitId: UUID?
    
    /// The quote text.
    var text: String
    
    var createdAt: Date
    
    init(
        book: Book? = nil,
        readingUnitId: UUID? = nil,
        text: String
    ) {
        self.id = UUID()
        self.book = book
        self.readingUnitId = readingUnitId
        self.text = text
        self.createdAt = Date()
    }
}
