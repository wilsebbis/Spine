import SwiftUI
import SwiftData

// MARK: - Paths View
// Journey selection screen — users choose a curated reading path,
// not browse a generic library. Each path is a commitment to a
// themed set of classics with visible progress and clear structure.

struct PathsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingPath.sortOrder) private var paths: [ReadingPath]
    @Query private var books: [Book]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Hero section
                    heroSection
                    
                    // Active paths (in progress)
                    let activePaths = paths.filter { $0.isStarted(books: books) }
                    if !activePaths.isEmpty {
                        pathSection(title: "Your Journeys", paths: activePaths)
                    }
                    
                    // Available paths (not started)
                    let availablePaths = paths.filter { !$0.isStarted(books: books) }
                    if !availablePaths.isEmpty {
                        pathSection(title: "Start a Journey", paths: availablePaths)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Paths")
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            Image(systemName: "map.fill")
                .font(.system(size: 32))
                .foregroundStyle(SpineTokens.Colors.accentGold)
            
            Text("Choose Your Path")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Each path is a guided journey through a themed collection of classics. Pick one and start reading today.")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.lg)
        }
        .padding(.vertical, SpineTokens.Spacing.md)
    }
    
    // MARK: - Path Section
    
    private func pathSection(title: String, paths: [ReadingPath]) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text(title)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            ForEach(paths) { path in
                NavigationLink(destination: PathDetailView(path: path)) {
                    PathCard(path: path, books: books)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Path Card

struct PathCard: View {
    let path: ReadingPath
    let books: [Book]
    
    private var progress: Double { path.progress(books: books) }
    private var isStarted: Bool { path.isStarted(books: books) }
    private var finished: Int { path.booksFinished(books: books) }
    private var total: Int { path.bookIds.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            HStack(spacing: SpineTokens.Spacing.md) {
                // Path icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold,
                                    (Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: path.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                    Text(path.title)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Text(path.subtitle)
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Progress or difficulty
                if isStarted {
                    VStack(spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
                        Text("\(finished)/\(total)")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                } else {
                    Text(path.difficulty.emoji)
                        .font(.title2)
                }
            }
            
            // Progress bar (only if started)
            if isStarted {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(SpineTokens.Colors.warmStone.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Bottom metadata
            HStack(spacing: SpineTokens.Spacing.sm) {
                Label("\(total) books", systemImage: "books.vertical")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                Label("~\(path.estimatedWeeks) weeks", systemImage: "calendar")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                Spacer()
                
                Text(path.difficulty.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: path.difficulty.color) ?? .gray)
                    .clipShape(Capsule())
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}



