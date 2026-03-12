import SwiftUI
import SwiftData

// MARK: - Public Profile View
// Shareable reading stats card showing books read, streak, XP, and top genres.
// Can be shared as a snapshot image via ShareLink.

struct PublicProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @Query private var xpProfiles: [XPProfile]
    @Query private var settings: [UserSettings]
    
    private var xpProfile: XPProfile? { xpProfiles.first }
    
    private var stats: OverallStats {
        let tracker = ProgressTracker(modelContext: modelContext)
        return tracker.overallStats(books: books)
    }
    
    private var topGenres: [String] {
        var genreCounts: [String: Int] = [:]
        for book in books where book.readingProgress?.isFinished == true {
            for genre in book.genres {
                genreCounts[genre, default: 0] += 1
            }
        }
        return genreCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Profile card
                    profileCard
                    
                    // Share button
                    ShareLink(
                        item: profileShareText,
                        subject: Text("My Spine Reading Stats"),
                        message: Text("Check out my reading progress on Spine!")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Profile")
                                .font(SpineTokens.Typography.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                    
                    // Reading stats
                    statsSection
                    
                    // Finished books
                    finishedBooks
                }
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Public Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Level badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text("\(xpProfile?.currentLevel ?? 1)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: SpineTokens.Colors.accentGold.opacity(0.4), radius: 8)
            }
            
            Text(xpProfile?.levelTitle ?? "Bookworm")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            // Quick stats row
            HStack(spacing: SpineTokens.Spacing.xl) {
                VStack {
                    Text("\(stats.booksFinished)")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("books")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                VStack {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(SpineTokens.Colors.streakFlame)
                        Text("\(stats.currentStreak)")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                    }
                    Text("streak")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                VStack {
                    Text("\(xpProfile?.totalXP ?? 0)")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("XP")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            
            // Top genres
            if !topGenres.isEmpty {
                HStack(spacing: SpineTokens.Spacing.xs) {
                    ForEach(topGenres, id: \.self) { genre in
                        Text(genre)
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                            .padding(.horizontal, SpineTokens.Spacing.sm)
                            .padding(.vertical, SpineTokens.Spacing.xxs)
                            .background(SpineTokens.Colors.warmStone.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpineTokens.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            StatCard(
                value: "\(Int(xpProfile?.averageWPM ?? 0))",
                label: "Avg WPM",
                systemImage: "gauge.with.dots.needle.67percent"
            )
            StatCard(
                value: "\(stats.totalReadingDays)",
                label: "Days",
                systemImage: "calendar"
            )
            StatCard(
                value: "\(stats.totalHighlights)",
                label: "Highlights",
                systemImage: "highlighter"
            )
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Finished Books
    
    private var finishedBooks: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Completed Books")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            let finished = books.filter { $0.readingProgress?.isFinished == true }
            
            if finished.isEmpty {
                Text("No books finished yet — keep reading!")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            } else {
                ForEach(finished) { book in
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        if let coverData = book.coverImageData,
                           let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 32, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        VStack(alignment: .leading) {
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
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SpineTokens.Colors.successGreen)
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Share Text
    
    private var profileShareText: String {
        """
        📚 My Spine Reading Stats
        Level \(xpProfile?.currentLevel ?? 1) — \(xpProfile?.levelTitle ?? "Bookworm")
        📖 \(stats.booksFinished) books finished
        🔥 \(stats.currentStreak) day streak
        ⭐ \(xpProfile?.totalXP ?? 0) XP
        """
    }
}
