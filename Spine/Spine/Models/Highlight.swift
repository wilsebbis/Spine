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
import Foundation
import SwiftData

/// Persisted chat message for "Ask the Book" conversations.
/// Messages are associated with a Book, allowing history to be
/// retained across sessions and cleared on demand.
@Model
final class BookChatMessage {
    @Attribute(.unique) var id: UUID
    var book: Book?
    
    /// The message text.
    var text: String
    
    /// Whether this message was sent by the user (true) or the AI (false).
    var isUser: Bool
    
    var createdAt: Date
    
    init(book: Book? = nil, text: String, isUser: Bool) {
        self.id = UUID()
        self.book = book
        self.text = text
        self.isUser = isUser
        self.createdAt = Date()
    }
}

/// Persisted local discussion post for chapter discussions.
/// Stores user comments per book+unit so they survive sheet dismissal.
@Model
final class LocalDiscussionPost {
    @Attribute(.unique) var id: UUID
    var book: Book?
    
    /// The unit ordinal this post belongs to.
    var unitOrdinal: Int
    
    /// Author display name.
    var authorName: String
    
    /// The comment text.
    var text: String
    
    /// Number of likes.
    var likeCount: Int
    
    /// Whether the current user liked this post.
    var isLikedByUser: Bool
    
    var createdAt: Date
    
    init(book: Book? = nil, unitOrdinal: Int, authorName: String = "You", text: String) {
        self.id = UUID()
        self.book = book
        self.unitOrdinal = unitOrdinal
        self.authorName = authorName
        self.text = text
        self.likeCount = 0
        self.isLikedByUser = false
        self.createdAt = Date()
    }
}
