import SwiftUI
import SwiftData

// MARK: - Onboarding View
// First-launch flow: Welcome → Reading Goal → First Book → Jump to reading.
// Goal: user reaches first reading session as fast as possible.

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var books: [Book]
    
    @State private var currentPage = 0
    @State private var maxAllowedPage = 0  // Only CTA buttons advance this
    @State private var selectedGoal: ReadingGoal = .tenMinutes
    @State private var isCompleted = false
    
    private var currentSettings: UserSettings? { settings.first }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    SpineTokens.Colors.cream,
                    SpineTokens.Colors.parchment,
                    SpineTokens.Colors.warmStone.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                goalPage.tag(1)
                tastePage.tag(2)
                startPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentPage) { oldValue, newValue in
                // Block forward swiping past allowed page
                if newValue > maxAllowedPage {
                    withAnimation { currentPage = maxAllowedPage }
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.log(.onboardingStarted)
        }
    }
    
    // MARK: - Welcome Page
    
    private var welcomePage: some View {
        VStack(spacing: SpineTokens.Spacing.xl) {
            Spacer()
            
            // Logo / Icon
            ZStack {
                Circle()
                    .fill(SpineTokens.Colors.accentGold.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
            
            VStack(spacing: SpineTokens.Spacing.sm) {
                Text("Spine")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("Build a reading spine.")
                    .font(SpineTokens.Typography.title3)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            VStack(spacing: SpineTokens.Spacing.xs) {
                featureRow(icon: "clock", text: "Daily reading in just 5-10 minutes")
                featureRow(icon: "flame.fill", text: "Build streaks and track progress")
                featureRow(icon: "book.closed", text: "Actually finish the classics")
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            
            Spacer()
            
            Button {
                withAnimation { maxAllowedPage = 1; currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.bottom, SpineTokens.Spacing.lg)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(SpineTokens.Colors.accentGold)
                .frame(width: 28)
            
            Text(text)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Spacer()
        }
        .padding(.vertical, SpineTokens.Spacing.xs)
    }
    
    // MARK: - Goal Page
    
    private var goalPage: some View {
        VStack(spacing: SpineTokens.Spacing.xl) {
            Spacer()
            
            VStack(spacing: SpineTokens.Spacing.sm) {
                Text("Set Your Daily Goal")
                    .font(SpineTokens.Typography.largeTitle)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("How much time can you commit to reading each day?")
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: SpineTokens.Spacing.sm) {
                ForEach(ReadingGoal.allCases, id: \.self) { goal in
                    goalOption(goal)
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            
            Spacer()
            
            Button {
                withAnimation { maxAllowedPage = 2; currentPage = 2 }
            } label: {
                Text("Continue")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.bottom, SpineTokens.Spacing.lg)
        }
    }
    
    // MARK: - Taste Page
    
    private var tastePage: some View {
        TasteOnboardingView {
            withAnimation { maxAllowedPage = 3; currentPage = 3 }
        }
    }
    
    private func goalOption(_ goal: ReadingGoal) -> some View {
        Button {
            selectedGoal = goal
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                    Text(goal.displayLabel)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Text(goal.description)
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        selectedGoal == goal ? SpineTokens.Colors.accentGold : SpineTokens.Colors.warmStone
                    )
                    .font(.title3)
            }
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
    }
    
    // MARK: - Start Page
    
    private var startPage: some View {
        VStack(spacing: SpineTokens.Spacing.xl) {
            Spacer()
            
            VStack(spacing: SpineTokens.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                Text("You're Ready")
                    .font(SpineTokens.Typography.largeTitle)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("Import a classic from Project Gutenberg, or browse your Library to begin.")
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpineTokens.Spacing.lg)
            }
            
            // Show seeded books
            if !books.isEmpty {
                VStack(spacing: SpineTokens.Spacing.xs) {
                    Text("Starter Library")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SpineTokens.Spacing.sm) {
                            ForEach(books.prefix(6)) { book in
                                BookCoverPlaceholder(
                                    title: book.title,
                                    author: book.author,
                                    size: CGSize(width: 80, height: 120)
                                )
                            }
                        }
                        .padding(.horizontal, SpineTokens.Spacing.md)
                    }
                }
            }
            
            Spacer()
            
            Button {
                completeOnboarding()
            } label: {
                Text("Start Reading")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.bottom, SpineTokens.Spacing.lg)
        }
    }
    
    // MARK: - Complete Onboarding
    
    private func completeOnboarding() {
        if let settings = currentSettings {
            settings.readingGoal = selectedGoal
            settings.hasCompletedOnboarding = true
            try? modelContext.save()
        }
        
        AnalyticsService.shared.log(.onboardingCompleted, properties: [
            "readingGoal": selectedGoal.displayLabel
        ])
        AnalyticsService.shared.log(.readingGoalSelected, properties: [
            "minutes": String(selectedGoal.rawValue)
        ])
    }
}
