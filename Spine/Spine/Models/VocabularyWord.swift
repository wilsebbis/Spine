import Foundation
import SwiftData

// MARK: - Vocabulary Word
// A word saved from reading, entering a spaced repetition deck.
// Reduces intimidation — a key thing a paperback can't do.

@Model
final class VocabularyWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var definition: String
    var contextSentence: String     // The sentence it appeared in
    var book: Book?
    var readingUnit: ReadingUnit?
    
    // SRS scheduling
    var srsInterval: Int            // Days until next review
    var nextReviewDate: Date
    var easeFactor: Double          // Multiplier (starts at 2.5)
    var reviewCount: Int
    var correctCount: Int
    
    var createdAt: Date
    
    /// Current mastery level based on review performance.
    var mastery: Mastery {
        if reviewCount == 0 { return .new }
        let ratio = correctCount > 0 ? Double(correctCount) / Double(reviewCount) : 0
        if ratio >= 0.9 && reviewCount >= 4 { return .mastered }
        if ratio >= 0.7 { return .familiar }
        return .learning
    }
    
    enum Mastery: String, Codable, Sendable {
        case new = "New"
        case learning = "Learning"
        case familiar = "Familiar"
        case mastered = "Mastered"
        
        var emoji: String {
            switch self {
            case .new: return "🆕"
            case .learning: return "📖"
            case .familiar: return "🌱"
            case .mastered: return "✅"
            }
        }
        
        var color: String {
            switch self {
            case .new: return "9E9E9E"
            case .learning: return "FF9800"
            case .familiar: return "2196F3"
            case .mastered: return "4CAF50"
            }
        }
    }
    
    init(
        word: String,
        definition: String,
        contextSentence: String,
        book: Book? = nil,
        readingUnit: ReadingUnit? = nil
    ) {
        self.id = UUID()
        self.word = word
        self.definition = definition
        self.contextSentence = contextSentence
        self.book = book
        self.readingUnit = readingUnit
        self.srsInterval = 1
        self.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        self.easeFactor = 2.5
        self.reviewCount = 0
        self.correctCount = 0
        self.createdAt = Date()
    }
    
    // MARK: - SRS Logic
    
    /// Record a review result and update scheduling.
    /// Quality: 0 = forgot, 1 = hard, 2 = good, 3 = easy
    func recordReview(quality: Int) {
        reviewCount += 1
        
        if quality >= 2 {
            correctCount += 1
        }
        
        // SM-2 inspired scheduling
        switch quality {
        case 0: // Forgot — reset
            srsInterval = 1
            easeFactor = max(1.3, easeFactor - 0.2)
        case 1: // Hard
            srsInterval = max(1, srsInterval)
            easeFactor = max(1.3, easeFactor - 0.15)
        case 2: // Good
            srsInterval = reviewCount <= 1 ? 1 : Int(Double(srsInterval) * easeFactor)
            easeFactor = easeFactor + 0.1
        case 3: // Easy
            srsInterval = Int(Double(srsInterval) * easeFactor * 1.3)
            easeFactor = easeFactor + 0.15
        default:
            break
        }
        
        srsInterval = min(srsInterval, 365) // Cap at 1 year
        nextReviewDate = Calendar.current.date(byAdding: .day, value: srsInterval, to: Date()) ?? Date()
    }
    
    /// Whether this word is due for review.
    var isDueForReview: Bool {
        nextReviewDate <= Date()
    }
}
