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
    @Query(sort: \League.createdAt, order: .reverse) private var leagues: [League]
    
    private var stats: OverallStats {
        let tracker = ProgressTracker(modelContext: modelContext)
        return tracker.overallStats(books: books)
    }
    
    private var currentSettings: UserSettings? { settings.first }
    private var xpProfile: XPProfile? { xpProfiles.first }
    
    @State private var showingVocabulary = false
    @State private var showingPaywall = false
    @State private var showingReferral = false
    
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
                    
                    // MARK: - League Badge
                    leagueBadge
                    
                    // MARK: - Reading Calendar
                    calendarSection
                    
                    // MARK: - Reading Goal
                    goalSection
                    
                    // MARK: - Recent Activity
                    recentActivity
                    
                    // MARK: - Quick Actions
                    quickActions
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingVocabulary) {
                VocabularyDeckView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingReferral) {
                ReferralView()
            }
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
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Daily Ritual")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            // Ritual progress
            if let goal = currentSettings?.readingGoal {
                let todayMinutes = stats.todayReadingMinutes
                let goalMinutes = Double(goal.rawValue)
                let progress = min(todayMinutes / goalMinutes, 1.0)
                
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                    // Progress arc
                    HStack(spacing: SpineTokens.Spacing.md) {
                        ZStack {
                            Circle()
                                .stroke(SpineTokens.Colors.warmStone.opacity(0.2), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    SpineTokens.Colors.accentGold,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            if progress >= 1.0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                            } else {
                                Text("\(Int(todayMinutes))m")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                            }
                        }
                        .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if progress >= 1.0 {
                                Text("Ritual complete for today ✓")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.successGreen)
                            } else {
                                Text("\(Int(todayMinutes)) of \(Int(goalMinutes)) minutes of your daily ritual")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                            }
                            
                            Text("\(currentSettings?.dailyXPGoal ?? 30) XP target · \(xpProfile?.dailyXP ?? 0) earned today")
                                .font(.system(size: 10))
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
            }
            
            // Week-day streak dots (M–Su)
            weekDayStreakDots
            
            // Recovery / milestone messaging
            if stats.currentStreak == 0 {
                Text("Welcome back — let's restart the rhythm")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.streakFlame)
            } else if stats.currentStreak == 1 && stats.longestStreak > 1 {
                Text("You're rebuilding — keep it going tomorrow")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.accentAmber)
            } else if stats.longestStreak > 0 && stats.currentStreak >= stats.longestStreak - 2 && stats.currentStreak < stats.longestStreak {
                Text("You're \(stats.longestStreak - stats.currentStreak) day\(stats.longestStreak - stats.currentStreak == 1 ? "" : "s") from a new personal best")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.successGreen)
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Week Day Streak Dots
    
    private var weekDayStreakDots: some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            let calendar = Calendar.current
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            // Monday = index 0
            let mondayOffset = (weekday + 5) % 7
            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            
            ForEach(0..<7, id: \.self) { index in
                let isToday = index == mondayOffset
                let isPast = index < mondayOffset
                let didRead = isPast && stats.currentStreak > (mondayOffset - index)
                
                VStack(spacing: 2) {
                    Text(dayLabels[index])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(
                            isToday ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray
                        )
                    
                    Circle()
                        .fill(
                            didRead ? SpineTokens.Colors.accentGold :
                            isToday ? SpineTokens.Colors.espresso :
                            SpineTokens.Colors.warmStone.opacity(0.2)
                        )
                        .frame(width: 10, height: 10)
                        .overlay {
                            if didRead {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - League Badge
    
    private var leagueBadge: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("League")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            if let league = leagues.first(where: { $0.isCurrentWeek }) {
                HStack(spacing: SpineTokens.Spacing.md) {
                    // Tier badge
                    ZStack {
                        Circle()
                            .fill(
                                Color(hex: league.tier.colorHex).opacity(0.2)
                            )
                            .frame(width: 56, height: 56)
                        
                        Text(league.tier.emoji)
                            .font(.system(size: 28))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(league.tier.rawValue)
                            .font(SpineTokens.Typography.title3)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        Text("\(league.weeklyXP) XP this week")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    Spacer()
                    
                    // Rank
                    if league.rank > 0 {
                        VStack(spacing: 2) {
                            Text("#\(league.rank)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                            Text("of \(league.totalParticipants)")
                                .font(.system(size: 10))
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
            } else {
                // No league yet — teaser
                HStack(spacing: SpineTokens.Spacing.md) {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundStyle(SpineTokens.Colors.warmStone)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Join Your First League")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("Complete lessons to earn your rank")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("More")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            // Vocabulary Deck
            actionRow(
                icon: "text.book.closed.fill",
                label: "Vocabulary Deck",
                subtitle: "Review saved words",
                color: SpineTokens.Colors.accentGold
            ) {
                showingVocabulary = true
            }
            
            // Highlights (moved from tab bar)
            NavigationLink {
                HighlightsView()
            } label: {
                HStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "highlighter")
                        .font(.body)
                        .foregroundStyle(SpineTokens.Colors.accentAmber)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Highlights")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("Your saved passages")
                            .font(.system(size: 10))
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(SpineTokens.Colors.warmStone)
                }
            }
            
            // Premium
            actionRow(
                icon: "crown.fill",
                label: "Spine Premium",
                subtitle: PremiumManager.shared.isPremium ? "Active" : "Upgrade for unlimited reading",
                color: SpineTokens.Colors.accentGold
            ) {
                showingPaywall = true
            }
            
            // Invite Friends
            actionRow(
                icon: "person.2.fill",
                label: "Invite Friends",
                subtitle: "Share Spine, earn free Premium",
                color: SpineTokens.Colors.successGreen
            ) {
                showingReferral = true
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    private func actionRow(icon: String, label: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpineTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(SpineTokens.Colors.warmStone)
            }
        }
        .buttonStyle(.plain)
    }
}
