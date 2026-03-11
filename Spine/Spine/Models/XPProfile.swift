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

// MARK: - XP Level Table

enum XPLevelTable {
    static let levels: [(level: Int, xp: Int, title: String)] = [
        (1,     0,     "Bookworm"),
        (2,     50,    "Page Turner"),
        (3,     150,   "Chapter Chaser"),
        (4,     300,   "Story Seeker"),
        (5,     500,   "Novel Navigator"),
        (6,     750,   "Prose Pathfinder"),
        (7,     1100,  "Verse Voyager"),
        (8,     1500,  "Tome Traveler"),
        (9,     2000,  "Literary Lion"),
        (10,    2700,  "Saga Scholar"),
        (11,    3500,  "Epic Explorer"),
        (12,    4500,  "Canon Keeper"),
        (13,    5500,  "Spine Master"),
        (14,    7000,  "Archive Architect"),
        (15,    9000,  "Grand Librarian"),
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
        levels.first(where: { $0.level == level })?.xp ?? 10000
    }
}
