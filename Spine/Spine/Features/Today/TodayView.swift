import SwiftUI
import SwiftData

// MARK: - Today View
// The Duolingo-inspired home screen showing daily XP progress,
// reading speed, streak, and today's reading assignment.

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @Query private var settings: [UserSettings]
    @Query private var xpProfiles: [XPProfile]
    
    @State private var showingReader = false
    @State private var activeBook: Book?
    @State private var activeUnit: ReadingUnit?
    
    private var currentSettings: UserSettings? { settings.first }
    private var xpProfile: XPProfile? { xpProfiles.first }
    
    private var activeReadingBook: Book? {
        if let activeId = currentSettings?.activeBookId {
            return books.first { $0.id == activeId }
        }
        return books.first { $0.importStatus == .completed && $0.readingProgress?.isFinished != true }
    }
    
    private var todayUnit: ReadingUnit? {
        guard let book = activeReadingBook else { return nil }
        let tracker = ProgressTracker(modelContext: modelContext)
        return tracker.todaysUnit(for: book)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // MARK: - Header with XP
                    header
                    
                    // MARK: - XP + Stats Row
                    if let profile = xpProfile {
                        xpStatsRow(profile: profile)
                    }
                    
                    if let book = activeReadingBook, let unit = todayUnit {
                        // MARK: - Today's Reading Card
                        todayCard(book: book, unit: unit)
                        
                        // MARK: - Progress Section
                        progressSection(book: book)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationDestination(isPresented: $showingReader) {
                if let book = activeBook, let unit = activeUnit {
                    ReaderView(book: book, initialUnit: unit)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                Text(greeting)
                    .font(SpineTokens.Typography.largeTitle)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text(dateString)
                    .font(SpineTokens.Typography.callout)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            Spacer()
            
            // Daily XP ring
            if let profile = xpProfile {
                DailyXPRing(
                    dailyXP: profile.dailyXP,
                    goal: currentSettings?.dailyXPGoal ?? 30
                )
            }
        }
        .padding(.top, SpineTokens.Spacing.md)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }
    
    private var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    
    // MARK: - XP Stats Row
    
    private func xpStatsRow(profile: XPProfile) -> some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            // XP Progress bar
            XPProgressBar(
                currentXP: profile.totalXP,
                levelXP: profile.xpForCurrentLevel,
                nextLevelXP: profile.xpForNextLevel,
                level: profile.currentLevel,
                title: profile.levelTitle
            )
            
            // Quick stats
            HStack(spacing: SpineTokens.Spacing.sm) {
                // Streak
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(SpineTokens.Colors.streakFlame)
                    let stats = ProgressTracker(modelContext: modelContext).overallStats(books: books)
                    Text("\(stats.currentStreak)")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundColor(SpineTokens.Colors.espresso)
                }
                
                Divider().frame(height: 14)
                
                // WPM
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.caption)
                        .foregroundColor(SpineTokens.Colors.accentGold)
                    Text("\(Int(profile.averageWPM)) WPM")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundColor(SpineTokens.Colors.espresso)
                }
                
                Divider().frame(height: 14)
                
                // Consistency
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(SpineTokens.Colors.successGreen)
                    Text("\(Int(profile.consistencyScore * 100))%")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundColor(SpineTokens.Colors.espresso)
                }
                
                Divider().frame(height: 14)
                
                // Total XP
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(SpineTokens.Colors.accentAmber)
                    Text("\(profile.totalXP) XP")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundColor(SpineTokens.Colors.espresso)
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Today Card
    
    private func todayCard(book: Book, unit: ReadingUnit) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Book info
            HStack(alignment: .top, spacing: SpineTokens.Spacing.md) {
                // Cover
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                } else {
                    BookCoverPlaceholder(
                        title: book.title,
                        author: book.author,
                        size: CGSize(width: 60, height: 88)
                    )
                }
                
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                    Text(unit.title)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .lineLimit(2)
                    
                    Text(book.title)
                        .font(SpineTokens.Typography.callout)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    
                    Spacer()
                    
                    // Lesson count + milestone
                    VStack(alignment: .leading, spacing: 2) {
                        let completed = book.readingProgress?.completedUnitCount ?? 0
                        let total = book.unitCount
                        Text("Lesson \(completed + 1) of \(total)")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        // Milestone proximity
                        if let chapter = unit.chapter {
                            let chapterUnits = chapter.readingUnits.count
                            let chapterDone = chapter.readingUnits.filter { $0.isCompleted }.count
                            let remaining = chapterUnits - chapterDone
                            if remaining > 0 && remaining <= 3 {
                                Text("\(remaining) lesson\(remaining == 1 ? "" : "s") from finishing \(chapter.title)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(SpineTokens.Colors.successGreen)
                            }
                        }
                    }
                    
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        Label(
                            "\(Int(ceil(unit.estimatedMinutes))) min",
                            systemImage: "clock"
                        )
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                        
                        Label("+25 XP", systemImage: "star.fill")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.accentAmber)
                    }
                }
                
                Spacer()
            }
            
            // Streak recovery message
            if let progress = book.readingProgress,
               progress.currentStreak == 1,
               (progress.completedUnitCount ?? 0) > 1 {
                Text("You're rebuilding your streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.streakFlame)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // CTA Button
            Button {
                activeBook = book
                activeUnit = unit
                showingReader = true
            } label: {
                HStack {
                    Image(systemName: unit.ordinal == 0 ? "book.fill" : "arrow.right")
                    Text(unit.ordinal == 0 ? "Start Today's Lesson" : "Resume Today's Lesson")
                        .font(SpineTokens.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.espresso)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
    }
    
    // MARK: - Progress Section
    
    private func progressSection(book: Book) -> some View {
        HStack(spacing: SpineTokens.Spacing.lg) {
            // Progress ring
            ZStack {
                ProgressRing(
                    progress: book.readingProgress?.completedPercent ?? 0,
                    lineWidth: 8,
                    size: 80
                )
                
                VStack(spacing: 0) {
                    Text("\(Int((book.readingProgress?.completedPercent ?? 0) * 100))%")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("done")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                // Streak
                StreakBadge(
                    count: book.readingProgress?.currentStreak ?? 0,
                    isActive: (book.readingProgress?.currentStreak ?? 0) > 0
                )
                
                // Progress
                let completed = book.readingProgress?.completedUnitCount ?? 0
                let total = book.unitCount
                let pct = Int((book.readingProgress?.completedPercent ?? 0) * 100)
                Text("\(pct)% through \(book.title)")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                Text("\(completed) of \(total) lessons completed")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                if let lastRead = book.readingProgress?.lastReadAt {
                    Text("Last read \(lastRead.formatted(.relative(presentation: .named)))")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            
            Spacer()
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text("Your reading journey starts here")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
                .multilineTextAlignment(.center)
            
            Text("Import a classic from your Library to begin your daily reading ritual.")
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
            
            Spacer()
        }
        .frame(minHeight: 300)
    }
}
