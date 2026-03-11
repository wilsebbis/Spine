import Foundation
import SwiftData

/// Records a single reading session for streak and analytics purposes.
/// One session per day per book-unit combination.
@Model
final class DailySession {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var readingUnitId: UUID?
    
    /// The calendar date of the session (day-level precision).
    var sessionDate: Date
    
    /// When the user started reading.
    var startedAt: Date
    
    /// When the user finished (nil if abandoned).
    var completedAt: Date?
    
    /// Total minutes spent reading in this session.
    var minutesSpent: Double
    
    var isCompleted: Bool {
        completedAt != nil
    }
    
    init(
        book: Book? = nil,
        readingUnitId: UUID? = nil,
        sessionDate: Date = Date()
    ) {
        self.id = UUID()
        self.book = book
        self.readingUnitId = readingUnitId
        self.sessionDate = Calendar.current.startOfDay(for: sessionDate)
        self.startedAt = Date()
        self.minutesSpent = 0
    }
}
