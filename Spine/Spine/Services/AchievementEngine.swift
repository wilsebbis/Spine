import Foundation

// MARK: - Achievement Engine
// Static achievement definitions and unlock logic.
// Duolingo-inspired badge system for reading milestones.

struct Achievement: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String        // SF Symbol
    let description: String
    let category: Category
    
    enum Category: String, Sendable, CaseIterable {
        case streak = "Streaks"
        case milestone = "Milestones"
        case skill = "Skills"
        case lifestyle = "Lifestyle"
    }
}

struct AchievementEngine: Sendable {
    
    // MARK: - All Achievements
    
    static let all: [Achievement] = [
        // Milestones
        Achievement(id: "first_unit", name: "First Steps", icon: "figure.walk", description: "Complete your first reading unit", category: .milestone),
        Achievement(id: "units_10", name: "Getting Started", icon: "figure.walk", description: "Complete 10 reading units", category: .milestone),
        Achievement(id: "units_50", name: "Dedicated", icon: "figure.run", description: "Complete 50 reading units", category: .milestone),
        Achievement(id: "units_100", name: "Centurion", icon: "medal", description: "Complete 100 reading units", category: .milestone),
        Achievement(id: "book_1", name: "One Down", icon: "book.closed.fill", description: "Finish your first book", category: .milestone),
        Achievement(id: "book_5", name: "Shelf Builder", icon: "books.vertical.fill", description: "Finish 5 books", category: .milestone),
        
        // Streaks
        Achievement(id: "streak_3", name: "On a Roll", icon: "flame", description: "3-day reading streak", category: .streak),
        Achievement(id: "streak_7", name: "Week Warrior", icon: "flame.fill", description: "7-day reading streak", category: .streak),
        Achievement(id: "streak_14", name: "Fortnight Force", icon: "bolt.fill", description: "14-day reading streak", category: .streak),
        Achievement(id: "streak_30", name: "Iron Will", icon: "trophy.fill", description: "30-day reading streak", category: .streak),
        
        // Skills
        Achievement(id: "speed_200", name: "Swift Reader", icon: "hare", description: "Read at 200+ WPM", category: .skill),
        Achievement(id: "speed_300", name: "Speed Demon", icon: "speedometer", description: "Read at 300+ WPM", category: .skill),
        Achievement(id: "xp_100", name: "Century", icon: "star.circle.fill", description: "Earn 100 XP in one day", category: .skill),
        Achievement(id: "consistent_7", name: "Rock Solid", icon: "diamond.fill", description: "Hit daily goal 7 days straight", category: .skill),
        
        // Lifestyle
        Achievement(id: "night_owl", name: "Night Owl", icon: "moon.fill", description: "Read after 10 PM", category: .lifestyle),
        Achievement(id: "early_bird", name: "First Light", icon: "sunrise.fill", description: "Read before 7 AM", category: .lifestyle),
    ]
    
    static func achievement(for id: String) -> Achievement? {
        all.first(where: { $0.id == id })
    }
    
    // MARK: - Check Unlocks
    
    /// Check all achievements and return newly unlocked ones.
    @MainActor
    func checkUnlocks(
        profile: XPProfile,
        totalUnitsCompleted: Int,
        booksFinished: Int,
        currentStreak: Int,
        sessionWPM: Double,
        readingHour: Int
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        
        func tryUnlock(_ id: String) {
            guard !profile.hasAchievement(id),
                  let achievement = Self.achievement(for: id) else { return }
            profile.unlockAchievement(id)
            newlyUnlocked.append(achievement)
        }
        
        // Milestones
        if totalUnitsCompleted >= 1 { tryUnlock("first_unit") }
        if totalUnitsCompleted >= 10 { tryUnlock("units_10") }
        if totalUnitsCompleted >= 50 { tryUnlock("units_50") }
        if totalUnitsCompleted >= 100 { tryUnlock("units_100") }
        if booksFinished >= 1 { tryUnlock("book_1") }
        if booksFinished >= 5 { tryUnlock("book_5") }
        
        // Streaks
        if currentStreak >= 3 { tryUnlock("streak_3") }
        if currentStreak >= 7 { tryUnlock("streak_7") }
        if currentStreak >= 14 { tryUnlock("streak_14") }
        if currentStreak >= 30 { tryUnlock("streak_30") }
        
        // Skills
        if sessionWPM >= 200 { tryUnlock("speed_200") }
        if sessionWPM >= 300 { tryUnlock("speed_300") }
        if profile.dailyXP >= 100 { tryUnlock("xp_100") }
        if profile.dailyGoalHitsThisWeek >= 7 { tryUnlock("consistent_7") }
        
        // Lifestyle
        if readingHour >= 22 || readingHour < 4 { tryUnlock("night_owl") }
        if readingHour >= 4 && readingHour < 7 { tryUnlock("early_bird") }
        
        return newlyUnlocked
    }
}
