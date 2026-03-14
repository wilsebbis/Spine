import Foundation
import SwiftData

// MARK: - Season
// Themed seasonal reading events.
// Creates urgency and novelty — keeps the app feeling alive
// and gives users new reasons to return beyond streaks.

@Model
final class Season {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var seasonDescription: String
    var iconName: String
    var themeColorHex: String
    var startDate: Date
    var endDate: Date
    var challengeBookIds: [UUID]
    var rewardBadgeId: String?    // Badge earned for completing
    var createdAt: Date
    
    init(
        title: String,
        subtitle: String,
        description: String,
        iconName: String,
        themeColorHex: String,
        startDate: Date,
        endDate: Date,
        challengeBookIds: [UUID] = []
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.seasonDescription = description
        self.iconName = iconName
        self.themeColorHex = themeColorHex
        self.startDate = startDate
        self.endDate = endDate
        self.challengeBookIds = challengeBookIds
        self.createdAt = Date()
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }
    
    var progress: Double {
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }
}

// MARK: - Buddy Challenge
// Async reading races between friends.
// Creates lightweight accountability without heavy social features.

@Model
final class BuddyChallenge {
    @Attribute(.unique) var id: UUID
    var challengeType: ChallengeType
    var title: String
    var creatorId: String
    var opponentId: String
    var targetBookId: UUID?
    var targetPathId: UUID?
    var startDate: Date
    var endDate: Date?
    
    // Progress
    var creatorProgress: Double  // 0.0 - 1.0
    var opponentProgress: Double
    var winnerId: String?
    var isCompleted: Bool
    
    var createdAt: Date
    
    enum ChallengeType: String, Codable, Sendable {
        case raceBook = "Race to Finish"
        case weeklyLessons = "Weekly Lesson Count"
        case streakBattle = "Streak Battle"
        case pathRace = "Path Race"
        
        var emoji: String {
            switch self {
            case .raceBook: return "📖"
            case .weeklyLessons: return "⚡"
            case .streakBattle: return "🔥"
            case .pathRace: return "🗺️"
            }
        }
    }
    
    init(
        type: ChallengeType,
        title: String,
        creatorId: String,
        opponentId: String
    ) {
        self.id = UUID()
        self.challengeType = type
        self.title = title
        self.creatorId = creatorId
        self.opponentId = opponentId
        self.startDate = Date()
        self.creatorProgress = 0
        self.opponentProgress = 0
        self.isCompleted = false
        self.createdAt = Date()
    }
}
