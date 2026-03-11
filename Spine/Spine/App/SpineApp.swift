import SwiftUI
import SwiftData

// MARK: - SpineApp
// Entry point for the Spine reading app.
// Configures SwiftData, seeds the catalog, and routes between
// Onboarding and the main tab interface.

@main
struct SpineApp: App {
    
    var sharedModelContainer: ModelContainer = {
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
        ])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
    }
}

// MARK: - Content View
// Routes between onboarding and main app based on user state.

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    @State private var hasInitialized = false
    @State private var isIngesting = false
    
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
    }
    
    private func initializeApp() {
        // Create UserSettings if none exists
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
        
        // Seed the book catalog
        SeedCatalog.seedIfNeeded(modelContext: modelContext)
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
            
            Tab("Highlights", systemImage: "highlighter", value: 2) {
                HighlightsView()
            }
            
            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(SpineTokens.Colors.accentGold)
        .onChange(of: selectedTab) { _, newValue in
            let tabNames = ["Today", "Library", "Highlights", "Profile"]
            AnalyticsService.shared.log(.tabSelected, properties: [
                "tab": tabNames[min(newValue, tabNames.count - 1)]
            ])
        }
    }
}
