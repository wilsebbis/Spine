import Foundation
import SwiftData
import SwiftUI

/// A user-created highlight with an optional attached note.
///
/// Locators use character offsets into the ReadingUnit's plainText
/// to support future anchoring for AI retrieval and export.
@Model
final class Highlight {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var readingUnit: ReadingUnit?
    
    /// The highlighted text.
    var selectedText: String
    
    /// Start character offset within the reading unit's plain text.
    var startLocator: Int
    
    /// End character offset within the reading unit's plain text.
    var endLocator: Int
    
    /// User's note attached to the highlight, if any.
    var noteText: String?
    
    /// Hex color string for the highlight color.
    var colorHex: String
    
    var isFavorite: Bool
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        book: Book? = nil,
        readingUnit: ReadingUnit? = nil,
        selectedText: String,
        startLocator: Int,
        endLocator: Int,
        noteText: String? = nil,
        colorHex: String = "C49B5C"
    ) {
        self.id = UUID()
        self.book = book
        self.readingUnit = readingUnit
        self.selectedText = selectedText
        self.startLocator = startLocator
        self.endLocator = endLocator
        self.noteText = noteText
        self.colorHex = colorHex
        self.isFavorite = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
