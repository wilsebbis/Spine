import Foundation
import SwiftData

/// User preferences and onboarding state.
/// Persisted in SwiftData to survive reinstalls (CloudKit-backed in future).
enum ReadingGoal: Int, Codable, CaseIterable, Sendable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    
    var displayLabel: String {
        "\(rawValue) min/day"
    }
    
    var description: String {
        switch self {
        case .fiveMinutes: return "A gentle start"
        case .tenMinutes: return "The sweet spot"
        case .fifteenMinutes: return "Deep reader"
        }
    }
}

enum ReaderTheme: String, Codable, CaseIterable, Sendable {
    case light
    case sepia
    case dark
    
    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    
    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool
    var readingGoalRaw: Int
    
    // MARK: - Reader Preferences
    var readerThemeRaw: String
    var fontSize: Double
    var lineHeightMultiplier: Double
    var useSerifFont: Bool
    
    // MARK: - Typography Extras
    var marginSize: Double          // horizontal padding (16–48pt)
    var paragraphSpacing: Double    // multiplier for inter-paragraph gap (0.4–1.0)
    var useDyslexiaFont: Bool       // OpenDyslexic-style accessible font
    
    // MARK: - Line Guide / Reading Ruler
    var lineGuideEnabled: Bool
    var lineGuideBandHeight: Int    // 1 = 1 line, 2 = 2 lines, 3 = 3 lines
    var lineGuideDimAmount: Double  // 0.3–0.8 opacity of dimmed area
    
    // MARK: - Active Book
    var activeBookId: UUID?
    
    // MARK: - Reading Speed
    var wordsPerMinute: Int
    
    // MARK: - Gamification
    var dailyXPGoal: Int
    
    // MARK: - Notifications
    var dailyReminderEnabled: Bool
    var reminderHour: Int        // 0–23
    var reminderMinute: Int      // 0–59
    
    var readingGoal: ReadingGoal {
        get { ReadingGoal(rawValue: readingGoalRaw) ?? .tenMinutes }
        set { readingGoalRaw = newValue.rawValue }
    }
    
    var readerTheme: ReaderTheme {
        get { ReaderTheme(rawValue: readerThemeRaw) ?? .light }
        set { readerThemeRaw = newValue.rawValue }
    }
    
    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
        self.readingGoalRaw = ReadingGoal.tenMinutes.rawValue
        self.readerThemeRaw = ReaderTheme.light.rawValue
        self.fontSize = 18.0
        self.lineHeightMultiplier = 1.6
        self.useSerifFont = true
        self.marginSize = 24.0
        self.paragraphSpacing = 0.6
        self.useDyslexiaFont = false
        self.lineGuideEnabled = false
        self.lineGuideBandHeight = 2
        self.lineGuideDimAmount = 0.5
        self.wordsPerMinute = 225
        self.dailyXPGoal = 30
        self.dailyReminderEnabled = false
        self.reminderHour = 20    // 8 PM default
        self.reminderMinute = 0
        self.activeBookId = nil
    }
}
