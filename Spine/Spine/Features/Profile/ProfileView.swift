import SwiftUI
import SwiftData

// MARK: - Profile View
// Duolingo-inspired profile with level badge, XP stats,
// achievement gallery, reading calendar, and streak info.

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @Query private var settings: [UserSettings]
    @Query private var xpProfiles: [XPProfile]
    
    private var stats: OverallStats {
        let tracker = ProgressTracker(modelContext: modelContext)
        return tracker.overallStats(books: books)
    }
    
    private var currentSettings: UserSettings? { settings.first }
    private var xpProfile: XPProfile? { xpProfiles.first }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // MARK: - Level Header
                    levelHeader
                    
                    // MARK: - XP Progress
                    if let profile = xpProfile {
                        XPProgressBar(
                            currentXP: profile.totalXP,
                            levelXP: profile.xpForCurrentLevel,
                            nextLevelXP: profile.xpForNextLevel,
                            level: profile.currentLevel,
                            title: profile.levelTitle
                        )
                        .padding(.horizontal, SpineTokens.Spacing.md)
                    }
                    
                    // MARK: - Stats Grid
                    statsGrid
                    
                    // MARK: - Achievement Gallery
                    if let profile = xpProfile {
                        AchievementGallery(
                            unlockedIDs: Set(profile.unlockedAchievementIDs),
                            dates: profile.achievementDates
                        )
                    }
                    
                    // MARK: - Reading Calendar
                    calendarSection
                    
                    // MARK: - Reading Goal
                    goalSection
                    
                    // MARK: - Recent Activity
                    recentActivity
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }
    
    // MARK: - Level Header
    
    private var levelHeader: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Level badge
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SpineTokens.Colors.accentGold.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text("\(xpProfile?.currentLevel ?? 1)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: SpineTokens.Colors.accentGold.opacity(0.4), radius: 12)
            }
            
            VStack(spacing: SpineTokens.Spacing.xxs) {
                Text(xpProfile?.levelTitle ?? "Bookworm")
                    .font(SpineTokens.Typography.title)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("\(xpProfile?.totalXP ?? 0) Total XP")
                    .font(SpineTokens.Typography.callout)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            // Streak
            HStack(spacing: SpineTokens.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(
                        stats.currentStreak > 0 ? SpineTokens.Colors.streakFlame : SpineTokens.Colors.subtleGray
                    )
                Text("\(stats.currentStreak) day streak")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                if stats.longestStreak > stats.currentStreak {
                    Text("· Best: \(stats.longestStreak)")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpineTokens.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: SpineTokens.Spacing.sm) {
            StatCard(
                value: "\(Int(xpProfile?.averageWPM ?? 0))",
                label: "Avg WPM",
                systemImage: "gauge.with.dots.needle.67percent"
            )
            StatCard(
                value: "\(stats.booksFinished)",
                label: "Finished",
                systemImage: "checkmark.circle"
            )
            StatCard(
                value: "\(Int((xpProfile?.consistencyScore ?? 0) * 100))%",
                label: "Consistency",
                systemImage: "chart.bar.fill"
            )
            StatCard(
                value: "\(stats.totalReadingDays)",
                label: "Reading days",
                systemImage: "calendar"
            )
            StatCard(
                value: "\(stats.totalHighlights)",
                label: "Highlights",
                systemImage: "highlighter"
            )
            StatCard(
                value: "\(Int(xpProfile?.fastestWPM ?? 0))",
                label: "Best WPM",
                systemImage: "hare"
            )
        }
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Reading Activity")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            ReadingCalendar(sessions: stats.calendarMap)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, SpineTokens.Spacing.sm)
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Goal Section
    
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text("Daily Goals")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            HStack {
                // Reading time goal
                if let goal = currentSettings?.readingGoal {
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        Image(systemName: "clock")
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                        VStack(alignment: .leading) {
                            Text(goal.displayLabel)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            Text("Reading time")
                                .font(.system(size: 10))
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
                
                Spacer()
                
                // XP goal
                HStack(spacing: SpineTokens.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(SpineTokens.Colors.accentAmber)
                    VStack(alignment: .leading) {
                        Text("\(currentSettings?.dailyXPGoal ?? 30) XP/day")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("XP target")
                            .font(.system(size: 10))
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Recent Activity
    
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Currently Reading")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            let activeBooks = books.filter {
                $0.importStatus == .completed && $0.readingProgress?.isFinished != true
            }
            
            if activeBooks.isEmpty {
                Text("No books in progress")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            } else {
                ForEach(activeBooks) { book in
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        if let coverData = book.coverImageData,
                           let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 36, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            BookCoverPlaceholder(
                                title: book.title,
                                author: book.author,
                                size: CGSize(width: 36, height: 52)
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .lineLimit(1)
                            Text(book.author)
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text("\(Int((book.readingProgress?.completedPercent ?? 0) * 100))%")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
}
