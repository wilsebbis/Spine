import Foundation
import SwiftData

// MARK: - XP Engine
// Core XP computation service. Calculates XP rewards with bonuses,
// tracks reading speed, and detects level-ups.

struct XPReward: Sendable {
    let baseXP: Int
    let streakBonus: Int
    let speedBonus: Int
    let firstOfDayBonus: Int
    let bookFinishBonus: Int
    var totalXP: Int { baseXP + streakBonus + speedBonus + firstOfDayBonus + bookFinishBonus }
    
    let wpm: Double
    let didLevelUp: Bool
    let previousLevel: Int
    let newLevel: Int
    let newAchievements: [Achievement]
    
    /// Formatted breakdown for toast display
    var breakdownLines: [String] {
        var lines: [String] = []
        lines.append("+\(baseXP) XP reading")
        if streakBonus > 0 { lines.append("+\(streakBonus) streak bonus 🔥") }
        if speedBonus > 0 { lines.append("+\(speedBonus) speed bonus 💨") }
        if firstOfDayBonus > 0 { lines.append("+\(firstOfDayBonus) daily kickstart ☀️") }
        if bookFinishBonus > 0 { lines.append("+\(bookFinishBonus) book complete 📖") }
        return lines
    }
}

@MainActor
struct XPEngine {
    
    private let achievementEngine = AchievementEngine()
    
    // MARK: - Constants
    
    private enum Constants {
        static let baseUnitXP = 10
        static let streakBonusPerDay = 2
        static let streakBonusCap = 20
        static let speedBonusXP = 5
        static let firstOfDayXP = 5
        static let bookFinishXP = 50
        static let defaultDailyGoal = 30
    }
    
    // MARK: - Award XP
    
    /// Calculate and award XP for completing a reading unit.
    func awardXP(
        profile: XPProfile,
        unit: ReadingUnit,
        book: Book,
        minutesSpent: Double,
        currentStreak: Int,
        totalUnitsCompleted: Int,
        booksFinished: Int,
        dailyXPGoal: Int = 30
    ) -> XPReward {
        let previousLevel = profile.currentLevel
        
        // Base XP
        let baseXP = Constants.baseUnitXP
        
        // Streak bonus: +2 per streak day, capped at +20
        let streakBonus = min(currentStreak * Constants.streakBonusPerDay, Constants.streakBonusCap)
        
        // Speed bonus: +5 if faster than personal average
        let wpm = computeWPM(wordCount: unit.wordCount, minutes: minutesSpent)
        let speedBonus = (profile.averageWPM > 0 && wpm > profile.averageWPM)
            ? Constants.speedBonusXP : 0
        
        // First unit of day bonus
        let today = Calendar.current.startOfDay(for: Date())
        let firstOfDayBonus = profile.dailyXPDate < today ? Constants.firstOfDayXP : 0
        
        // Book finish bonus
        let allCompleted = book.readingUnits.allSatisfy { $0.isCompleted }
        let bookFinishBonus = allCompleted ? Constants.bookFinishXP : 0
        
        // Apply XP
        let totalXP = baseXP + streakBonus + speedBonus + firstOfDayBonus + bookFinishBonus
        profile.addXP(totalXP)
        
        // Update WPM
        profile.updateWPM(wpm)
        
        // Check daily goal hit
        if profile.dailyXP >= dailyXPGoal {
            let wasHitBefore = (profile.dailyXP - totalXP) >= dailyXPGoal
            if !wasHitBefore {
                profile.dailyGoalHitsThisWeek += 1
            }
        }
        
        // Update consistency
        profile.consistencyScore = Double(profile.dailyGoalHitsThisWeek) / 7.0
        
        // Check level up
        let newLevel = profile.currentLevel
        let didLevelUp = newLevel > previousLevel
        
        // Check achievements
        let hour = Calendar.current.component(.hour, from: Date())
        let newAchievements = achievementEngine.checkUnlocks(
            profile: profile,
            totalUnitsCompleted: totalUnitsCompleted,
            booksFinished: booksFinished + (bookFinishBonus > 0 ? 1 : 0),
            currentStreak: currentStreak,
            sessionWPM: wpm,
            readingHour: hour
        )
        
        return XPReward(
            baseXP: baseXP,
            streakBonus: streakBonus,
            speedBonus: speedBonus,
            firstOfDayBonus: firstOfDayBonus,
            bookFinishBonus: bookFinishBonus,
            wpm: wpm,
            didLevelUp: didLevelUp,
            previousLevel: previousLevel,
            newLevel: newLevel,
            newAchievements: newAchievements
        )
    }
    
    // MARK: - WPM
    
    func computeWPM(wordCount: Int, minutes: Double) -> Double {
        guard minutes > 0.1 else { return 0 }  // avoid division by near-zero
        return Double(wordCount) / minutes
    }
}
