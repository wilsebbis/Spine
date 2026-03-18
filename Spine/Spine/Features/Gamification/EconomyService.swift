import Foundation
import SwiftData

// MARK: - Economy Service
// Manages the Virtual Economy, soft currency (Pages), and Daily Passes.

@MainActor
final class EconomyService {
    static let shared = EconomyService()
    
    // Cost of one additional chapter read
    let dailyPassCost: Int = 100
    
    // Returns whether the user is allowed to read the provided unit today
    func canReadNextUnit(profile: XPProfile, unitsCompletedToday: Int) -> Bool {
        if PremiumManager.shared.isPremium { return true }
        
        let freeUnits = PremiumManager.shared.dailyLessonLimit // Usually 1
        let allowed = freeUnits + profile.dailyPassesBoughtToday
        return unitsCompletedToday < allowed
    }
    
    func buyDailyPass(profile: XPProfile) -> Bool {
        profile.resetDailyPassesIfNeeded()
        
        if profile.spendPages(dailyPassCost) {
            profile.dailyPassesBoughtToday += 1
            return true
        }
        return false
    }
}
