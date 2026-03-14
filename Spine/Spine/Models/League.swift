import Foundation
import SwiftData

// MARK: - League
// Weekly competitive tier system.
// Social pressure should feel motivating, not humiliating.
// Rank is based on normalized lesson XP, not raw books completed.

@Model
final class League {
    @Attribute(.unique) var id: UUID
    var tier: Tier
    var weeklyXP: Int
    var weekNumber: Int           // ISO week number
    var year: Int
    var rank: Int                 // 1-based rank in current league
    var totalParticipants: Int
    var promotedThisWeek: Bool
    var demotedThisWeek: Bool
    var createdAt: Date
    
    // MARK: - Tier
    
    enum Tier: String, Codable, CaseIterable, Sendable {
        case bronze = "Bronze"
        case silver = "Silver"
        case gold = "Gold"
        case sapphire = "Sapphire"
        case ruby = "Ruby"
        case diamond = "Diamond"
        
        var emoji: String {
            switch self {
            case .bronze: return "🥉"
            case .silver: return "🥈"
            case .gold: return "🥇"
            case .sapphire: return "💎"
            case .ruby: return "❤️‍🔥"
            case .diamond: return "💠"
            }
        }
        
        var colorHex: String {
            switch self {
            case .bronze: return "CD7F32"
            case .silver: return "C0C0C0"
            case .gold: return "FFD700"
            case .sapphire: return "0F52BA"
            case .ruby: return "E0115F"
            case .diamond: return "B9F2FF"
            }
        }
        
        var promoteThreshold: Int { 3 }  // Top 3 promote
        var demoteThreshold: Int { 20 }  // Bottom falls down
        
        var nextTier: Tier? {
            switch self {
            case .bronze: return .silver
            case .silver: return .gold
            case .gold: return .sapphire
            case .sapphire: return .ruby
            case .ruby: return .diamond
            case .diamond: return nil
            }
        }
        
        var previousTier: Tier? {
            switch self {
            case .bronze: return nil
            case .silver: return .bronze
            case .gold: return .silver
            case .sapphire: return .gold
            case .ruby: return .sapphire
            case .diamond: return .ruby
            }
        }
    }
    
    init(tier: Tier = .bronze, weekNumber: Int, year: Int) {
        self.id = UUID()
        self.tier = tier
        self.weeklyXP = 0
        self.weekNumber = weekNumber
        self.year = year
        self.rank = 0
        self.totalParticipants = 25
        self.promotedThisWeek = false
        self.demotedThisWeek = false
        self.createdAt = Date()
    }
    
    /// Add XP for this week.
    func addXP(_ amount: Int) {
        weeklyXP += amount
    }
    
    /// Whether this league entry is for the current week.
    var isCurrentWeek: Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.weekOfYear, from: now) == weekNumber
            && cal.component(.yearForWeekOfYear, from: now) == year
    }
}

// MARK: - Streak Shield
// Protects streaks on missed days.
// Free users get 1, premium users get 2.
// Shields are consumed automatically when a day is missed.

@Model
final class StreakShield {
    @Attribute(.unique) var id: UUID
    var availableShields: Int
    var maxShields: Int               // 1 for free, 2 for premium
    var lastConsumedDate: Date?
    var totalConsumed: Int
    var totalEarned: Int
    
    init(maxShields: Int = 1) {
        self.id = UUID()
        self.availableShields = maxShields
        self.maxShields = maxShields
        self.lastConsumedDate = nil
        self.totalConsumed = 0
        self.totalEarned = maxShields
    }
    
    /// Consume a shield to protect streak. Returns true if successful.
    @discardableResult
    func consumeShield() -> Bool {
        guard availableShields > 0 else { return false }
        availableShields -= 1
        lastConsumedDate = Date()
        totalConsumed += 1
        return true
    }
    
    /// Award a new shield (e.g., from completing a weekly challenge).
    func earnShield() {
        guard availableShields < maxShields else { return }
        availableShields += 1
        totalEarned += 1
    }
    
    /// Update max based on premium status.
    func updatePremiumStatus(isPremium: Bool) {
        maxShields = isPremium ? 2 : 1
        // Don't remove a shield they already have
    }
    
    var hasShield: Bool { availableShields > 0 }
}
