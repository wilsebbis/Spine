import Foundation

// MARK: - Feature Flags
// Clean interface for toggling features. MVP starts with all future features off.
// Phase 2-4 features can be activated without rewriting foundation.

struct FeatureFlags: Sendable {
    static let shared = FeatureFlags()
    
    // MARK: - Phase 1: Core Habit Engine (MVP - All ON)
    let epubIngestion = true
    let dailySegmentation = true
    let streakTracking = true
    let highlights = true
    let reactions = true
    
    // MARK: - Phase 2: Open Ecosystem + Foundational AI (ON)
    let arbitraryEPUBImport = true
    let defineWord = true
    let explainParagraph = true
    let unitRecap = true
    let librarySync = false
    
    // MARK: - Phase 3: Spoiler-Safe Intelligence (ON)
    let progressAwareRetrieval = true
    let characterGraph = true
    let askTheBook = true
    let xRay = true
    let advancedRecap = true
    
    // MARK: - Phase 4: Social Layer (ON)
    let chapterGatedDiscussions = true
    let readingClubs = true
    let publicProfiles = true
    let highlightSharing = true
    
    // MARK: - Utility
    
    func isEnabled(_ flag: KeyPath<FeatureFlags, Bool>) -> Bool {
        self[keyPath: flag]
    }
}

// MARK: - AI Service Protocol
// Clean interface for future AI features. Implementations can use
// local models (CoreML), OpenAI, or Anthropic.

protocol AIServiceProtocol: Sendable {
    func defineWord(_ word: String, context: String) async throws -> String
    func explainParagraph(_ text: String, bookTitle: String) async throws -> String
    func recapUnit(_ unitText: String, bookTitle: String) async throws -> String
    func askTheBook(
        question: String,
        bookTitle: String,
        readContentUpToUnit: Int,
        allUnitsText: [String]
    ) async throws -> String
}

/// Stub implementation that returns placeholder responses.
struct StubAIService: AIServiceProtocol {
    func defineWord(_ word: String, context: String) async throws -> String {
        "AI features will be available in a future update."
    }
    func explainParagraph(_ text: String, bookTitle: String) async throws -> String {
        "AI explanation will be available in Phase 2."
    }
    func recapUnit(_ unitText: String, bookTitle: String) async throws -> String {
        "AI-generated recap will be available in Phase 2."
    }
    func askTheBook(question: String, bookTitle: String, readContentUpToUnit: Int, allUnitsText: [String]) async throws -> String {
        "BookRAG will be available in Phase 3."
    }
}

// MARK: - Social Service Protocol

protocol SocialServiceProtocol: Sendable {
    func shareHighlight(highlightId: String, bookTitle: String) async throws
    func getDiscussion(bookId: String, unitOrdinal: Int) async throws -> [DiscussionPost]
    func postToDiscussion(bookId: String, unitOrdinal: Int, text: String) async throws
    func getPublicProfile(userId: String) async throws -> PublicProfile
}

struct DiscussionPost: Sendable {
    let id: String
    let authorName: String
    let text: String
    let timestamp: Date
}

struct PublicProfile: Sendable {
    let userId: String
    let displayName: String
    let booksRead: Int
    let currentStreak: Int
}

struct StubSocialService: SocialServiceProtocol {
    func shareHighlight(highlightId: String, bookTitle: String) async throws {}
    func getDiscussion(bookId: String, unitOrdinal: Int) async throws -> [DiscussionPost] { [] }
    func postToDiscussion(bookId: String, unitOrdinal: Int, text: String) async throws {}
    func getPublicProfile(userId: String) async throws -> PublicProfile {
        PublicProfile(userId: userId, displayName: "Reader", booksRead: 0, currentStreak: 0)
    }
}
