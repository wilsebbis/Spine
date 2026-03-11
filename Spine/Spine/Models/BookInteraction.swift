import Foundation
import SwiftData

// MARK: - Interaction Type

/// Every possible user-book signal we track for recommendations.
enum InteractionType: String, Codable, CaseIterable, Sendable {
    case finished        // completed the book
    case abandoned       // stopped reading (< 50% progress)
    case rated           // gave a star rating
    case reviewed        // wrote a text review
    case readLater       // added to "want to read"
    case dismissed       // "not interested" from recommendations
    case opened          // opened but didn't finish
}

// MARK: - Book Interaction

/// Records a single user-book interaction event.
/// These accumulate over time and feed into the recommendation engine.
@Model
final class BookInteraction {
    @Attribute(.unique) var id: UUID
    
    // MARK: Core Signal
    var interactionType: InteractionType
    var timestamp: Date
    
    // MARK: Rating & Review
    var rating: Int?                        // 1-5 stars (nil if not rated)
    var reviewText: String?                 // free-text review
    
    // MARK: Micro-Reasons
    var likedReasons: [String]              // ["prose", "characters", "atmosphere"]
    var dislikedReasons: [String]           // ["slow", "dense", "predictable"]
    
    // MARK: Behavioral Signals
    var dwellTimeSeconds: Double            // total time spent
    var completionPercent: Double           // 0.0–1.0
    
    // MARK: Relationships
    @Relationship var book: Book?
    
    init(
        interactionType: InteractionType,
        book: Book? = nil,
        rating: Int? = nil,
        reviewText: String? = nil,
        likedReasons: [String] = [],
        dislikedReasons: [String] = [],
        dwellTimeSeconds: Double = 0,
        completionPercent: Double = 0
    ) {
        self.id = UUID()
        self.interactionType = interactionType
        self.timestamp = Date()
        self.book = book
        self.rating = rating
        self.reviewText = reviewText
        self.likedReasons = likedReasons
        self.dislikedReasons = dislikedReasons
        self.dwellTimeSeconds = dwellTimeSeconds
        self.completionPercent = completionPercent
    }
}
