import Foundation
import os.log

// MARK: - Analytics Service
// A swappable analytics abstraction. Ships with os_log for MVP,
// designed to be replaced with Mixpanel/Amplitude/PostHog later.

final class AnalyticsService: Sendable {
    
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: "com.spine.app", category: "analytics")
    
    /// All tracked events in Spine.
    enum Event: String, Sendable {
        // Onboarding
        case onboardingStarted = "onboarding_started"
        case onboardingCompleted = "onboarding_completed"
        case readingGoalSelected = "reading_goal_selected"
        
        // Import
        case bookImportStarted = "book_import_started"
        case bookImportCompleted = "book_import_completed"
        case bookImportFailed = "book_import_failed"
        
        // Reading
        case readingUnitOpened = "reading_unit_opened"
        case readingUnitCompleted = "reading_unit_completed"
        case readingSessionStarted = "reading_session_started"
        case readingSessionEnded = "reading_session_ended"
        
        // Engagement
        case highlightCreated = "highlight_created"
        case noteCreated = "note_created"
        case reactionSaved = "reaction_saved"
        case quoteSaved = "quote_saved"
        
        // Streaks
        case streakIncremented = "streak_incremented"
        case streakBroken = "streak_broken"
        
        // Navigation
        case tabSelected = "tab_selected"
        case bookOpened = "book_opened"
        case readerSettingsChanged = "reader_settings_changed"
    }
    
    /// Log an analytics event with optional properties.
    func log(_ event: Event, properties: [String: String] = [:]) {
        let propsString = properties.isEmpty ? "" : " | \(properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.info("📊 \(event.rawValue)\(propsString)")
        
        // Future: send to remote analytics provider
        // provider.track(event.rawValue, properties: properties)
    }
}
