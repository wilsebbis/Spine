import SwiftUI
import SwiftData
import MessageUI
import UIKit

// MARK: - SpineApp
// Entry point for the Spine reading app.
// Configures SwiftData, seeds the catalog, and routes between
// Onboarding and the main tab interface.

@main
struct SpineApp: App {
    
    @State private var quickAction: QuickAction? = nil
    
    var sharedModelContainer: ModelContainer = {
        // Ensure Application Support directory exists before CoreData tries to create the store
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        let schema = Schema([
            Book.self,
            Chapter.self,
            ReadingUnit.self,
            ReadingProgress.self,
            Highlight.self,
            DailySession.self,
            Reaction.self,
            QuoteSave.self,
            UserSettings.self,
            BookInteraction.self,
            UserTasteProfile.self,
            XPProfile.self,
            ReadingClub.self,
            BookChatMessage.self,
            LocalDiscussionPost.self,
            BookIntelligence.self,
            ReadingPath.self,
            VocabularyWord.self,
            League.self,
            StreakShield.self,
            Season.self,
            BuddyChallenge.self,
            AudiobookChapter.self,
            BookAudioFile.self,
        ])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(quickAction: $quickAction)
                .modelContainer(sharedModelContainer)
        }
    }
    
    enum QuickAction: String {
        case feedback = "com.spine.app.feedback"
        case share = "com.spine.app.share"
    }
}

// MARK: - Content View
// Routes between onboarding and main app based on user state.

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    @Binding var quickAction: SpineApp.QuickAction?
    
    @State private var hasInitialized = false
    @State private var isIngesting = false
    @State private var showFeedbackMail = false
    @State private var showShareSheet = false
    
    private var hasCompletedOnboarding: Bool {
        settings.first?.hasCompletedOnboarding ?? false
    }
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            guard !hasInitialized else { return }
            hasInitialized = true
            initializeApp()
            
            // Auto-ingest bundled EPUBs in the background
            await SeedCatalog.ingestBundledBooks(modelContext: modelContext)
        }
        .onChange(of: quickAction) { _, action in
            guard let action else { return }
            switch action {
            case .feedback:
                showFeedbackMail = true
            case .share:
                showShareSheet = true
            }
            quickAction = nil
        }
        .sheet(isPresented: $showFeedbackMail) {
            FeedbackMailView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSpineSheet()
        }
    }
    
    private func initializeApp() {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
        SeedCatalog.seedIfNeeded(modelContext: modelContext)
        SeedCatalog.enrichExistingBooks(modelContext: modelContext)
        
        // Pre-fetch cover thumbnails from Gutenberg in background
        CoverCacheService(modelContext: modelContext).prefetchCovers()
    }
}

// MARK: - Feedback Mail View

struct FeedbackMailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if MFMailComposeViewController.canSendMail() {
            MailComposerView(
                subject: "Spine App Feedback",
                toRecipients: ["support@wilsebbis.com"],
                body: """
                Hi Spine Team,
                
                I'd like to share some feedback:
                
                
                
                Device: \(UIDevice.current.model)
                iOS: \(UIDevice.current.systemVersion)
                """,
                onDismiss: { dismiss() }
            )
        } else {
            VStack(spacing: SpineTokens.Spacing.lg) {
                Capsule()
                    .fill(SpineTokens.Colors.warmStone)
                    .frame(width: 36, height: 4)
                    .padding(.top, SpineTokens.Spacing.sm)
                
                Image(systemName: "envelope.badge.person.crop")
                    .font(.system(size: 48))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                Text("Mail Not Available")
                    .font(SpineTokens.Typography.title)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("Email us at **support@wilsebbis.com**\nwith your feedback.")
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
                
                Button("Copy Email") {
                    UIPasteboard.general.string = "support@wilsebbis.com"
                }
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, SpineTokens.Spacing.xl)
                .padding(.vertical, SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.accentGold)
                .clipShape(Capsule())
                
                Spacer()
            }
            .padding(SpineTokens.Spacing.lg)
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Share Spine Sheet

struct ShareSpineSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Capsule()
                .fill(SpineTokens.Colors.warmStone)
                .frame(width: 36, height: 4)
                .padding(.top, SpineTokens.Spacing.sm)
            
            Image(systemName: "book.pages.fill")
                .font(.system(size: 48))
                .foregroundStyle(SpineTokens.Colors.accentGold)
            
            Text("Share Spine")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Recommend Spine to a friend")
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
            
            ShareLink(
                item: URL(string: "https://apps.apple.com/app/spine")!,
                subject: Text("Check out Spine"),
                message: Text("I've been reading with Spine \u{2014} it makes books feel like a game. Check it out!")
            ) {
                Label("Share App", systemImage: "square.and.arrow.up")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpineTokens.Spacing.xl)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(SpineTokens.Spacing.lg)
        .presentationDetents([.medium])
    }
}

// MARK: - Mail Composer UIKit Bridge

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let toRecipients: [String]
    let body: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setToRecipients(toRecipients)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onDismiss()
        }
    }
}

// MARK: - Main Tab View
// Bottom tab bar navigation with Liquid Glass styling.

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max.fill", value: 0) {
                TodayView()
            }
            
            Tab("Library", systemImage: "books.vertical.fill", value: 1) {
                LibraryView()
            }
            
            Tab("Discover", systemImage: "sparkle.magnifyingglass", value: 2) {
                NavigationStack {
                    CatalogView()
                }
            }
            
            Tab("Paths", systemImage: "map.fill", value: 3) {
                PathsView()
            }
            
            Tab("Social", systemImage: "person.2.fill", value: 4) {
                ReadingClubView()
            }
            
            Tab("Profile", systemImage: "person.fill", value: 5) {
                ProfileView()
            }
        }
        .tint(SpineTokens.Colors.accentGold)
        .onChange(of: selectedTab) { _, newValue in
            let tabNames = ["Today", "Library", "Discover", "Paths", "Social", "Profile"]
            AnalyticsService.shared.log(.tabSelected, properties: [
                "tab": tabNames[min(newValue, tabNames.count - 1)]
            ])
        }
    }
}
