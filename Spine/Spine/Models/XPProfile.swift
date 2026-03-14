import Foundation
import SwiftData

// MARK: - XP Profile
// Singleton model tracking XP, level, reading speed, consistency, and achievements.
// Duolingo-inspired progression system adapted for reading.

@Model
final class XPProfile {
    @Attribute(.unique) var id: UUID
    
    // MARK: - XP
    var totalXP: Int
    var dailyXP: Int
    var dailyXPDate: Date
    var weeklyXP: Int
    var weeklyXPReset: Date
    
    // MARK: - Speed
    var averageWPM: Double
    var totalReadingSessions: Int      // for rolling average
    var fastestWPM: Double
    
    // MARK: - Consistency
    var consistencyScore: Double       // 0.0–1.0, rolling 7-day
    var dailyGoalHitsThisWeek: Int
    
    // MARK: - Achievements
    var unlockedAchievementIDs: [String]
    var achievementDates: [String: Date]  // achievementID -> unlock date
    
    // MARK: - Computed
    
    var currentLevel: Int {
        XPLevelTable.level(for: totalXP)
    }
    
    var levelTitle: String {
        XPLevelTable.title(for: currentLevel)
    }
    
    var xpForCurrentLevel: Int {
        XPLevelTable.xpRequired(for: currentLevel)
    }
    
    var xpForNextLevel: Int {
        XPLevelTable.xpRequired(for: currentLevel + 1)
    }
    
    /// Progress within current level (0.0–1.0)
    var levelProgress: Double {
        let base = xpForCurrentLevel
        let next = xpForNextLevel
        guard next > base else { return 1.0 }
        return Double(totalXP - base) / Double(next - base)
    }
    
    init() {
        self.id = UUID()
        self.totalXP = 0
        self.dailyXP = 0
        self.dailyXPDate = Calendar.current.startOfDay(for: Date())
        self.weeklyXP = 0
        self.weeklyXPReset = Calendar.current.startOfDay(for: Date())
        self.averageWPM = 0
        self.totalReadingSessions = 0
        self.fastestWPM = 0
        self.consistencyScore = 0
        self.dailyGoalHitsThisWeek = 0
        self.unlockedAchievementIDs = []
        self.achievementDates = [:]
    }
    
    // MARK: - Mutations
    
    func addXP(_ amount: Int) {
        let previousLevel = currentLevel
        totalXP += amount
        
        // Reset daily if new day
        let today = Calendar.current.startOfDay(for: Date())
        if dailyXPDate < today {
            dailyXP = 0
            dailyXPDate = today
        }
        dailyXP += amount
        
        // Reset weekly if new week
        if let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
           weeklyXPReset < weekStart {
            weeklyXP = 0
            weeklyXPReset = weekStart
            dailyGoalHitsThisWeek = 0
        }
        weeklyXP += amount
        
        // Track if daily goal hit
        // (checked externally by XPEngine)
        
        let _ = previousLevel // suppress unused warning
    }
    
    func updateWPM(_ wpm: Double) {
        guard wpm > 0, wpm < 1500 else { return } // sanity check
        
        totalReadingSessions += 1
        
        if totalReadingSessions == 1 {
            averageWPM = wpm
        } else {
            // Exponential moving average (α = 0.3 for responsiveness)
            averageWPM = 0.3 * wpm + 0.7 * averageWPM
        }
        
        if wpm > fastestWPM {
            fastestWPM = wpm
        }
    }
    
    func unlockAchievement(_ id: String) {
        guard !unlockedAchievementIDs.contains(id) else { return }
        unlockedAchievementIDs.append(id)
        achievementDates[id] = Date()
    }
    
    func hasAchievement(_ id: String) -> Bool {
        unlockedAchievementIDs.contains(id)
    }
}

enum XPLevelTable {
    static let levels: [(level: Int, xp: Int, title: String)] = [
        // Reader tier (L1–5)
        (1,     0,      "Reader"),
        (2,     75,     "Page Turner"),
        (3,     200,    "Chapter Chaser"),
        (4,     400,    "Story Seeker"),
        (5,     700,    "Steady Reader"),
        // Scholar tier (L6–10)
        (6,     1100,   "Prose Explorer"),
        (7,     1600,   "Verse Voyager"),
        (8,     2200,   "Scholar"),
        (9,     3000,   "Literary Scout"),
        (10,    4000,   "Tome Traveler"),
        // Archivist tier (L11–15)
        (11,    5200,   "Canon Seeker"),
        (12,    6500,   "Archivist"),
        (13,    8000,   "Epic Explorer"),
        (14,    10000,  "Saga Keeper"),
        (15,    12500,  "Archive Architect"),
        // Classicist tier (L16–20)
        (16,    15500,  "Classicist"),
        (17,    19000,  "Canon Keeper"),
        (18,    23000,  "Literary Lion"),
        (19,    28000,  "Grand Reader"),
        (20,    34000,  "Spine Master"),
        // Canonmaster tier (L21–25)
        (21,    41000,  "Canon Climber"),
        (22,    49000,  "Great Books Sage"),
        (23,    58000,  "Canonmaster"),
        (24,    70000,  "Grand Librarian"),
        (25,    85000,  "Eternal Reader"),
    ]
    
    static func level(for xp: Int) -> Int {
        var result = 1
        for entry in levels {
            if xp >= entry.xp { result = entry.level }
            else { break }
        }
        return result
    }
    
    static func title(for level: Int) -> String {
        levels.first(where: { $0.level == level })?.title ?? "Reader"
    }
    
    static func xpRequired(for level: Int) -> Int {
        levels.first(where: { $0.level == level })?.xp ?? 100000
    }
}
