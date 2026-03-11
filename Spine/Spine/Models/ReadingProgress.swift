import Foundation
import SwiftData

/// Tracks reading progress for a single book.
/// One-to-one relationship with Book.
///
/// Streaks are calculated from DailySession records but cached here
/// for fast Today screen rendering.
@Model
final class ReadingProgress {
    @Attribute(.unique) var id: UUID
    var book: Book?
    
    /// The ID of the current (next to read) ReadingUnit.
    var currentUnitId: UUID?
    
    /// How many units the reader has completed.
    var completedUnitCount: Int
    
    /// Completion percentage (0.0...1.0).
    var completedPercent: Double
    
    /// Last time the reader read this book.
    var lastReadAt: Date?
    
    /// The anchor date for the current streak.
    var streakAnchorDate: Date?
    
    /// Current consecutive day streak.
    var currentStreak: Int
    
    /// All-time longest streak.
    var longestStreak: Int
    
    var isFinished: Bool {
        completedPercent >= 1.0
    }
    
    init(book: Book? = nil) {
        self.id = UUID()
        self.book = book
        self.completedUnitCount = 0
        self.completedPercent = 0.0
        self.currentStreak = 0
        self.longestStreak = 0
    }
    
    /// Advances progress after completing a unit.
    func markUnitCompleted(nextUnitId: UUID?, totalUnits: Int) {
        completedUnitCount += 1
        completedPercent = totalUnits > 0 ? Double(completedUnitCount) / Double(totalUnits) : 0.0
        currentUnitId = nextUnitId
        lastReadAt = Date()
    }
}
