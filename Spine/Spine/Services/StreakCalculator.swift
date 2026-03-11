import Foundation
import SwiftData

// MARK: - Streak Calculator
// Computes reading streaks from DailySession records.
// Handles timezone-aware day boundaries and gap detection.

struct StreakCalculator: Sendable {
    
    struct StreakResult: Sendable {
        let currentStreak: Int
        let longestStreak: Int
        let isActiveToday: Bool
        let readingDays: Set<Date>
    }
    
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    /// Calculate streaks from a list of daily sessions.
    func calculate(sessions: [DailySession]) -> StreakResult {
        guard !sessions.isEmpty else {
            return StreakResult(currentStreak: 0, longestStreak: 0, isActiveToday: false, readingDays: [])
        }
        
        // Get unique reading days (normalized to start of day)
        let readingDays: Set<Date> = Set(sessions.compactMap { session in
            guard session.isCompleted else { return nil }
            return calendar.startOfDay(for: session.sessionDate)
        })
        
        guard !readingDays.isEmpty else {
            return StreakResult(currentStreak: 0, longestStreak: 0, isActiveToday: false, readingDays: readingDays)
        }
        
        let sortedDays = readingDays.sorted()
        let today = calendar.startOfDay(for: Date())
        let isActiveToday = readingDays.contains(today)
        
        // Calculate current streak (counting backward from today or yesterday)
        let currentStreak = calculateCurrentStreak(sortedDays: sortedDays, today: today)
        
        // Calculate longest streak
        let longestStreak = calculateLongestStreak(sortedDays: sortedDays)
        
        return StreakResult(
            currentStreak: currentStreak,
            longestStreak: max(longestStreak, currentStreak),
            isActiveToday: isActiveToday,
            readingDays: readingDays
        )
    }
    
    private func calculateCurrentStreak(sortedDays: [Date], today: Date) -> Int {
        var streak = 0
        var checkDate = today
        
        // If today has a session, count it
        if sortedDays.contains(checkDate) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        } else {
            // Check yesterday (streak stays alive until end of today)
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if sortedDays.contains(checkDate) {
                streak = 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                return 0
            }
        }
        
        // Count consecutive days backward
        while sortedDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        return streak
    }
    
    private func calculateLongestStreak(sortedDays: [Date]) -> Int {
        guard sortedDays.count > 1 else { return sortedDays.count }
        
        var longest = 1
        var current = 1
        
        for i in 1..<sortedDays.count {
            let diff = calendar.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        
        return longest
    }
    
    /// Build a session map for the reading calendar heatmap.
    func buildCalendarMap(sessions: [DailySession]) -> [Date: Bool] {
        var map: [Date: Bool] = [:]
        for session in sessions where session.isCompleted {
            let day = calendar.startOfDay(for: session.sessionDate)
            map[day] = true
        }
        return map
    }
}
