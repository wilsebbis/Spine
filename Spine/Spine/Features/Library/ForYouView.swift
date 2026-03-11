import SwiftUI
import SwiftData

// MARK: - For You View
// Horizontal scroll of recommended books with rationale.
// Sits at the top of the Library tab.

struct ForYouView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasteProfiles: [UserTasteProfile]
    @Query private var allBooks: [Book]
    @Query private var interactions: [BookInteraction]
    
    @State private var recommendations: [ScoredBook] = []
    @State private var hasLoaded = false
    
    private let service = RecommendationService()
    
    private var tasteProfile: UserTasteProfile? {
        tasteProfiles.first
    }
    
    var body: some View {
        Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                    // Section header
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(SpineTokens.Colors.accentGold)
                        Text("For You")
                            .font(SpineTokens.Typography.headline)
                            .foregroundColor(SpineTokens.Colors.ink)
                    }
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    // Horizontal scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: SpineTokens.Spacing.md) {
                            ForEach(recommendations) { scored in
                                RecommendationCard(scored: scored)
                            }
                        }
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                    }
                }
                .padding(.vertical, SpineTokens.Spacing.sm)
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            loadRecommendations()
        }
        .onChange(of: allBooks.count) { _, _ in
            loadRecommendations()
        }
    }
    
    private func loadRecommendations() {
        guard let profile = tasteProfile else {
            // No taste profile yet — show popular books instead
            recommendations = allBooks
                .filter { !$0.chapters.isEmpty }
                .prefix(6)
                .map { ScoredBook(book: $0, score: 1.0, rationale: "A classic worth exploring") }
            return
        }
        
        recommendations = service.getRecommendations(
            tasteProfile: profile,
            allBooks: allBooks,
            interactions: interactions,
            limit: 8
        )
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let scored: ScoredBook
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink {
            // Navigate to reader on tap
            ReaderView(book: scored.book)
        } label: {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                // Cover or placeholder
                ZStack {
                    if let coverData = scored.book.coverImageData,
                       let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } else {
                        // Literary placeholder
                        RoundedRectangle(cornerRadius: SpineTokens.Radius.small)
                            .fill(
                                LinearGradient(
                                    colors: [SpineTokens.Colors.espresso, SpineTokens.Colors.charcoal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                VStack(spacing: SpineTokens.Spacing.xxs) {
                                    Text(scored.book.title)
                                        .font(SpineTokens.Typography.caption2)
                                        .foregroundColor(SpineTokens.Colors.accentGold)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .padding(.horizontal, SpineTokens.Spacing.xs)
                                    
                                    Text(scored.book.author)
                                        .font(.system(size: 9, design: .serif))
                                        .foregroundColor(SpineTokens.Colors.warmStone)
                                        .lineLimit(1)
                                }
                            }
                    }
                }
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                .shadow(color: SpineTokens.Shadows.medium, radius: 6, y: 3)
                
                // Title
                Text(scored.book.title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.ink)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                // Rationale
                Text(scored.rationale)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(SpineTokens.Colors.accentGold)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(SpineTokens.Animation.quick, value: isPressed)
    }
}
