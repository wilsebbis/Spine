import Foundation
import SwiftData

// MARK: - Three-Layer Feedback System
//
// Layer A: Pre-read intent (on BookDetailView before starting)
// Layer B: In-session reaction chips (while reading)
// Layer C: Post-read verdict (after completing a unit/book)
//
// Each layer is low-friction, one-tap, no typing.

// MARK: - Layer A: Pre-Read Intent

enum ReadingIntent: String, Codable, CaseIterable, Sendable {
    case wantToRead = "Want to read"
    case curious = "Curious"
    case assigned = "Assigned"
    case savingForLater = "Saving for later"
    case dnfForNow = "DNF for now"
    
    var emoji: String {
        switch self {
        case .wantToRead: return "📖"
        case .curious: return "🤔"
        case .assigned: return "📝"
        case .savingForLater: return "📌"
        case .dnfForNow: return "⏸️"
        }
    }
    
    var systemImage: String {
        switch self {
        case .wantToRead: return "book"
        case .curious: return "questionmark.circle"
        case .assigned: return "pencil.circle"
        case .savingForLater: return "bookmark"
        case .dnfForNow: return "pause.circle"
        }
    }
}

// MARK: - Layer B: In-Session Reaction (one-tap chips)

enum ReactionType: String, Codable, CaseIterable, Sendable {
    case lovedIt = "Loved it"
    case confused = "Confused"
    case beautifullyWritten = "Beautiful"
    case dark = "Dark"
    case funny = "Funny"
    case boring = "Boring"
    case important = "Important"
    case needSummary = "Need summary"
    
    var emoji: String {
        switch self {
        case .lovedIt: return "❤️"
        case .confused: return "😵"
        case .beautifullyWritten: return "✨"
        case .dark: return "🌑"
        case .funny: return "😄"
        case .boring: return "😴"
        case .important: return "📌"
        case .needSummary: return "📋"
        }
    }
    
    var systemImage: String {
        switch self {
        case .lovedIt: return "heart.fill"
        case .confused: return "questionmark.circle"
        case .beautifullyWritten: return "sparkles"
        case .dark: return "moon.fill"
        case .funny: return "face.smiling"
        case .boring: return "zzz"
        case .important: return "exclamationmark.circle"
        case .needSummary: return "doc.text"
        }
    }
}

// MARK: - Layer C: Post-Read Verdict

enum ReadingVerdict: String, Codable, CaseIterable, Sendable {
    case worthIt = "Worth it"
    case gladIReadIt = "Glad I read it"
    case hardButRewarding = "Hard but rewarding"
    case notForMe = "Not for me"
    case wantToDiscuss = "Want to discuss"
    case recommendBeginner = "Good for beginners"
    case recommendAdvanced = "For advanced readers"
    
    var emoji: String {
        switch self {
        case .worthIt: return "🔥"
        case .gladIReadIt: return "😊"
        case .hardButRewarding: return "💪"
        case .notForMe: return "🤷"
        case .wantToDiscuss: return "💬"
        case .recommendBeginner: return "🌱"
        case .recommendAdvanced: return "🎓"
        }
    }
    
    var systemImage: String {
        switch self {
        case .worthIt: return "flame"
        case .gladIReadIt: return "hand.thumbsup"
        case .hardButRewarding: return "figure.strengthtraining.traditional"
        case .notForMe: return "xmark.circle"
        case .wantToDiscuss: return "bubble.left.and.bubble.right"
        case .recommendBeginner: return "leaf"
        case .recommendAdvanced: return "graduationcap"
        }
    }
}

// MARK: - Reaction Model (Layer B — persisted)

@Model
final class Reaction {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var readingUnit: ReadingUnit?
    
    /// The type of emotional reaction (Layer B).
    var reactionTypeRaw: String
    
    /// Post-read verdict (Layer C), set on unit/book completion.
    var verdictRaw: String?
    
    var createdAt: Date
    
    var reactionType: ReactionType? {
        get { ReactionType(rawValue: reactionTypeRaw) }
        set { reactionTypeRaw = newValue?.rawValue ?? "" }
    }
    
    var verdict: ReadingVerdict? {
        get { verdictRaw.flatMap { ReadingVerdict(rawValue: $0) } }
        set { verdictRaw = newValue?.rawValue }
    }
    
    init(
        book: Book? = nil,
        readingUnit: ReadingUnit? = nil,
        reactionType: ReactionType
    ) {
        self.id = UUID()
        self.book = book
        self.readingUnit = readingUnit
        self.reactionTypeRaw = reactionType.rawValue
        self.createdAt = Date()
    }
}

