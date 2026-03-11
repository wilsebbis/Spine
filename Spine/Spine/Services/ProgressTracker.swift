import Foundation
import SwiftData

// MARK: - Progress Tracker
// Handles reading progress computation and daily session management.

@MainActor
final class ProgressTracker {
    
    private let modelContext: ModelContext
    private let streakCalculator = StreakCalculator()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Start Session
    
    /// Start a reading session for a specific unit.
    func startSession(for book: Book, unit: ReadingUnit) -> DailySession {
        AnalyticsService.shared.log(.readingSessionStarted, properties: [
            "bookTitle": book.title,
            "unitOrdinal": String(unit.ordinal)
        ])
        
        let session = DailySession(
            book: book,
            readingUnitId: unit.id
        )
        modelContext.insert(session)
        return session
    }
    
    // MARK: - Complete Unit
    
    /// Mark a reading unit as completed and update all progress records.
    func completeUnit(
        _ unit: ReadingUnit,
        book: Book,
        session: DailySession,
        minutesSpent: Double
    ) {
        // Mark unit completed
        unit.isCompleted = true
        unit.completedAt = Date()
        
        // Update session
        session.completedAt = Date()
        session.minutesSpent = minutesSpent
        
        // Update progress
        if let progress = book.readingProgress {
            let sortedUnits = book.sortedUnits
            let nextUnit = sortedUnits.first { !$0.isCompleted && $0.ordinal > unit.ordinal }
            progress.markUnitCompleted(
                nextUnitId: nextUnit?.id,
                totalUnits: sortedUnits.count
            )
            
            // Update streak
            let streakResult = streakCalculator.calculate(sessions: book.dailySessions)
            progress.currentStreak = streakResult.currentStreak
            progress.longestStreak = streakResult.longestStreak
            progress.streakAnchorDate = Calendar.current.startOfDay(for: Date())
            
            if streakResult.currentStreak > 0 {
                AnalyticsService.shared.log(.streakIncremented, properties: [
                    "streak": String(streakResult.currentStreak)
                ])
            }
        }
        
        try? modelContext.save()
        
        AnalyticsService.shared.log(.readingUnitCompleted, properties: [
            "bookTitle": book.title,
            "unitOrdinal": String(unit.ordinal),
            "minutesSpent": String(format: "%.1f", minutesSpent)
        ])
    }
    
    // MARK: - Queries
    
    /// Get today's reading unit for a book.
    func todaysUnit(for book: Book) -> ReadingUnit? {
        guard let progress = book.readingProgress,
              let currentId = progress.currentUnitId else {
            return book.sortedUnits.first
        }
        return book.readingUnits.first { $0.id == currentId }
    }
    
    /// Get overall reading statistics across all books.
    func overallStats(books: [Book]) -> OverallStats {
        let totalSessions = books.flatMap(\.dailySessions)
        let streakResult = streakCalculator.calculate(sessions: totalSessions)
        
        let booksStarted = books.filter { !$0.readingUnits.isEmpty }.count
        let booksFinished = books.filter { $0.readingProgress?.isFinished == true }.count
        let totalHighlights = books.reduce(0) { $0 + $1.highlights.count }
        
        return OverallStats(
            currentStreak: streakResult.currentStreak,
            longestStreak: streakResult.longestStreak,
            booksStarted: booksStarted,
            booksFinished: booksFinished,
            totalReadingDays: streakResult.readingDays.count,
            totalHighlights: totalHighlights,
            isActiveToday: streakResult.isActiveToday,
            calendarMap: streakResult.readingDays.reduce(into: [:]) { $0[$1] = true }
        )
    }
}

// MARK: - Stats Model

struct OverallStats: Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let booksStarted: Int
    let booksFinished: Int
    let totalReadingDays: Int
    let totalHighlights: Int
    let isActiveToday: Bool
    let calendarMap: [Date: Bool]
}
