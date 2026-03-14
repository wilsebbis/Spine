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
        static let baseUnitXP = 25
        static let difficultyBonusXP = 10        // for units > 3000 words
        static let streakBonusPerDay = 3
        static let streakBonusCap = 30
        static let speedBonusXP = 5
        static let firstOfDayXP = 10
        static let bookFinishXP = 150
        static let focusBonusXP = 5               // uninterrupted session
        static let defaultDailyGoal = 50
        static let minSessionSeconds = 60.0       // anti-exploit floor
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
        
        // Anti-exploit: no XP for sessions under 60 seconds
        guard minutesSpent * 60 >= Constants.minSessionSeconds else {
            return XPReward(
                baseXP: 0, streakBonus: 0, speedBonus: 0,
                firstOfDayBonus: 0, bookFinishBonus: 0,
                wpm: 0, didLevelUp: false,
                previousLevel: previousLevel, newLevel: previousLevel,
                newAchievements: []
            )
        }
        
        // Base XP + difficulty bonus for dense units
        let baseXP = Constants.baseUnitXP
            + (unit.wordCount > 3000 ? Constants.difficultyBonusXP : 0)
        
        // Streak bonus: +3 per streak day, capped at +30
        let streakBonus = min(currentStreak * Constants.streakBonusPerDay, Constants.streakBonusCap)
        
        // Speed bonus: +5 if faster than personal average
        let wpm = computeWPM(wordCount: unit.wordCount, minutes: minutesSpent)
        let speedBonus = (profile.averageWPM > 0 && wpm > profile.averageWPM)
            ? Constants.speedBonusXP : 0
        
        // First unit of day bonus (+10)
        let today = Calendar.current.startOfDay(for: Date())
        let firstOfDayBonus = profile.dailyXPDate < today ? Constants.firstOfDayXP : 0
        
        // Book finish bonus (+150)
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
    
    // MARK: - Physical Book XP
    
    /// Award XP for completing a physical book chapter.
    /// Simplified — no WPM since we can't measure reading speed on paper.
    func awardPhysicalChapterXP(
        profile: XPProfile,
        book: Book,
        currentStreak: Int
    ) -> XPReward {
        let previousLevel = profile.currentLevel
        
        // Base: 20 XP per physical chapter (slightly less than digital since no WPM verification)
        let baseXP = 20
        
        // Streak bonus
        let streakBonus = min(currentStreak * Constants.streakBonusPerDay, Constants.streakBonusCap)
        
        // First of day bonus
        let today = Calendar.current.startOfDay(for: Date())
        let firstOfDayBonus = profile.dailyXPDate < today ? Constants.firstOfDayXP : 0
        
        // Book finish bonus — completing all chapters
        let isFinished = book.physicalCurrentChapter >= book.totalPhysicalChapters
        let bookFinishBonus = isFinished ? Constants.bookFinishXP : 0
        
        // Apply XP
        let totalXP = baseXP + streakBonus + firstOfDayBonus + bookFinishBonus
        profile.addXP(totalXP)
        
        // Check level up
        let newLevel = profile.currentLevel
        let didLevelUp = newLevel > previousLevel
        
        // Check achievements
        let hour = Calendar.current.component(.hour, from: Date())
        let booksFinished = isFinished ? 1 : 0
        let newAchievements = achievementEngine.checkUnlocks(
            profile: profile,
            totalUnitsCompleted: profile.totalXP / 25,  // approximation
            booksFinished: booksFinished,
            currentStreak: currentStreak,
            sessionWPM: 0,
            readingHour: hour
        )
        
        return XPReward(
            baseXP: baseXP,
            streakBonus: streakBonus,
            speedBonus: 0,
            firstOfDayBonus: firstOfDayBonus,
            bookFinishBonus: bookFinishBonus,
            wpm: 0,
            didLevelUp: didLevelUp,
            previousLevel: previousLevel,
            newLevel: newLevel,
            newAchievements: newAchievements
        )
    }
}
