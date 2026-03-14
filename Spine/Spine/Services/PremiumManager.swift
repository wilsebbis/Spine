import Foundation
import Observation

// MARK: - Premium Manager
// Controls access to premium features.
// Premium value is about convenience, scaffolding, and habit support —
// NOT text access (the text is already free).

@MainActor
@Observable
final class PremiumManager {
    static let shared = PremiumManager()
    
    var isPremium: Bool = false
    var trialDaysRemaining: Int? = nil
    
    // MARK: - Feature Gates
    
    /// Number of lessons allowed per day for free users.
    var dailyLessonLimit: Int { isPremium ? .max : 1 }
    
    /// Whether unlimited path access is available.
    var hasFullCatalog: Bool { isPremium }
    
    /// Whether advanced annotations are available.
    var hasAdvancedAnnotations: Bool { isPremium }
    
    /// Whether audio read-along is available.
    var hasAudioReadAlong: Bool { isPremium }
    
    /// Whether offline reading is available.
    var hasOfflineReading: Bool { isPremium }
    
    /// Maximum streak shields.
    var maxStreakShields: Int { isPremium ? 2 : 1 }
    
    /// Whether deeper AI companion features are available.
    var hasAdvancedAICompanion: Bool { isPremium }
    
    /// Whether premium buddy features are available.
    var hasPremiumSocial: Bool { isPremium }
    
    /// Whether vocabulary review is unlimited.
    var hasUnlimitedVocab: Bool { isPremium }
    
    /// Whether ads are shown.
    var showsAds: Bool { !isPremium }
    
    /// Number of saved quotes allowed.
    var maxSavedQuotes: Int { isPremium ? .max : 10 }
    
    // MARK: - Premium Actions
    
    /// Check if user can start another lesson today.
    func canStartLesson(lessonsCompletedToday: Int) -> Bool {
        return lessonsCompletedToday < dailyLessonLimit
    }
    
    /// Simulate starting a trial.
    func startTrial() {
        isPremium = true
        trialDaysRemaining = 14
    }
    
    /// Simulate purchasing premium.
    func purchase() {
        // TODO: StoreKit 2 integration
        isPremium = true
        trialDaysRemaining = nil
    }
    
    /// Simulate restoring purchases.
    func restorePurchases() {
        // TODO: StoreKit 2 restore
    }
    
    /// Gift premium to a friend (placeholder).
    func giftPremium(toFriendId: String, days: Int) {
        // TODO: Backend integration
        print("🎁 Gifting \(days) days of premium to \(toFriendId)")
    }
}
