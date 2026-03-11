import Foundation
import SwiftData

// MARK: - Pace Preference

enum PacePreference: String, Codable, CaseIterable, Sendable {
    case short      // < 50K words
    case medium     // 50K–100K
    case long       // 100K+
    case any        // no preference
}

// MARK: - Genre/Vibe Weight

/// A preference with a normalized weight (0.0–1.0).
/// Stored as JSON-encoded array in SwiftData.
struct TasteWeight: Codable, Sendable, Equatable {
    var name: String
    var weight: Double  // 0.0–1.0, higher = stronger preference
    
    init(name: String, weight: Double = 1.0) {
        self.name = name
        self.weight = min(1.0, max(0.0, weight))
    }
}

// MARK: - User Taste Profile

/// Aggregated preference vector derived from onboarding choices
/// and ongoing interaction signals. Single instance per user.
@Model
final class UserTasteProfile {
    @Attribute(.unique) var id: UUID
    
    // MARK: Genre Preferences (from onboarding + interactions)
    var preferredGenres: [TasteWeight]
    
    // MARK: Vibe Preferences (positive signals)
    var preferredVibes: [TasteWeight]
    
    // MARK: Avoided Vibes (negative signals from onboarding + micro-reasons)
    var avoidedVibes: [String]
    
    // MARK: Reading Pace
    var pacePreference: PacePreference
    
    // MARK: Timestamps
    var createdAt: Date
    var lastUpdated: Date
    
    // MARK: Onboarding State
    var hasCompletedTasteOnboarding: Bool
    
    init() {
        self.id = UUID()
        self.preferredGenres = []
        self.preferredVibes = []
        self.avoidedVibes = []
        self.pacePreference = .any
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.hasCompletedTasteOnboarding = false
    }
    
    // MARK: - Mutation API
    
    /// Set genres from onboarding selection. Equal weights initially.
    func setOnboardingGenres(_ genres: [String]) {
        preferredGenres = genres.map { TasteWeight(name: $0, weight: 1.0) }
        lastUpdated = Date()
    }
    
    /// Set vibes from onboarding selection.
    func setOnboardingVibes(liked: [String], avoided: [String]) {
        preferredVibes = liked.map { TasteWeight(name: $0, weight: 1.0) }
        avoidedVibes = avoided
        lastUpdated = Date()
    }
    
    /// Boost a vibe/genre based on a positive interaction signal.
    func reinforceVibe(_ vibe: String, boost: Double = 0.1) {
        if let idx = preferredVibes.firstIndex(where: { $0.name == vibe }) {
            preferredVibes[idx].weight = min(1.0, preferredVibes[idx].weight + boost)
        } else {
            preferredVibes.append(TasteWeight(name: vibe, weight: 0.5 + boost))
        }
        lastUpdated = Date()
    }
    
    /// Penalize a vibe based on a negative interaction signal.
    func penalizeVibe(_ vibe: String) {
        if let idx = preferredVibes.firstIndex(where: { $0.name == vibe }) {
            preferredVibes[idx].weight = max(0.0, preferredVibes[idx].weight - 0.15)
            if preferredVibes[idx].weight < 0.1 {
                preferredVibes.remove(at: idx)
                if !avoidedVibes.contains(vibe) {
                    avoidedVibes.append(vibe)
                }
            }
        }
        lastUpdated = Date()
    }
}
