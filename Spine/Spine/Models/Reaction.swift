import Foundation
import SwiftData

/// Post-reading emotional reactions to a reading unit.
/// These are lightweight affective signals — designed for the user's
/// own reflection first, and future social sharing second.
enum ReactionType: String, Codable, CaseIterable, Sendable {
    case lovedIt = "Loved it"
    case confused = "Confused"
    case beautifullyWritten = "Beautifully written"
    case dark = "Dark"
    case funny = "Funny"
    case dense = "Dense"
    
    var emoji: String {
        switch self {
        case .lovedIt: return "❤️"
        case .confused: return "🤔"
        case .beautifullyWritten: return "✨"
        case .dark: return "🌑"
        case .funny: return "😄"
        case .dense: return "📚"
        }
    }
    
    var systemImage: String {
        switch self {
        case .lovedIt: return "heart.fill"
        case .confused: return "questionmark.circle"
        case .beautifullyWritten: return "sparkles"
        case .dark: return "moon.fill"
        case .funny: return "face.smiling"
        case .dense: return "books.vertical"
        }
    }
}

@Model
final class Reaction {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var readingUnit: ReadingUnit?
    
    /// The type of emotional reaction.
    var reactionTypeRaw: String
    
    /// Optional reflection text.
    var reflectionText: String?
    
    var createdAt: Date
    
    var reactionType: ReactionType? {
        get { ReactionType(rawValue: reactionTypeRaw) }
        set { reactionTypeRaw = newValue?.rawValue ?? "" }
    }
    
    init(
        book: Book? = nil,
        readingUnit: ReadingUnit? = nil,
        reactionType: ReactionType,
        reflectionText: String? = nil
    ) {
        self.id = UUID()
        self.book = book
        self.readingUnit = readingUnit
        self.reactionTypeRaw = reactionType.rawValue
        self.reflectionText = reflectionText
        self.createdAt = Date()
    }
}
