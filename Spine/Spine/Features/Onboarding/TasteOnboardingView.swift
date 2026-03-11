import SwiftUI
import SwiftData

// MARK: - Taste Onboarding View
// Two-step genre + vibe chip selection during onboarding.
// Feeds into UserTasteProfile for initial recommendation seeding.

struct TasteOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step: TasteStep = .genres
    @State private var selectedGenres: Set<String> = []
    @State private var selectedVibes: Set<String> = []
    @State private var avoidedVibes: Set<String> = []
    @State private var showAvoidedSection = false
    
    var onComplete: () -> Void
    
    enum TasteStep {
        case genres, vibes
    }
    
    // MARK: - Available Options
    
    static let genres = [
        "Romance", "Adventure", "Philosophy", "Horror",
        "Sci-Fi", "Poetry", "Drama", "Humor",
        "Mystery", "History", "Fantasy", "Literary Fiction"
    ]
    
    static let positiveVibes = [
        "Beautiful prose", "Strong characters", "Plot twists",
        "Philosophical", "Cozy", "Dark",
        "Fast-paced", "Emotional", "Experimental",
        "Atmospheric", "Witty", "Epic"
    ]
    
    static let negativeVibes = [
        "Too slow", "Too dense", "Too romantic",
        "Too bleak", "Too long", "Overhyped"
    ]
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            // Progress indicator
            HStack(spacing: SpineTokens.Spacing.xs) {
                Capsule()
                    .fill(SpineTokens.Colors.accentGold)
                    .frame(height: 3)
                Capsule()
                    .fill(step == .vibes ? SpineTokens.Colors.accentGold : SpineTokens.Colors.warmStone)
                    .frame(height: 3)
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.top, SpineTokens.Spacing.md)
            
            switch step {
            case .genres:
                genresStep
            case .vibes:
                vibesStep
            }
            
            Spacer()
            
            // Continue button
            Button(action: handleContinue) {
                HStack {
                    Text(step == .genres ? "Next" : "Start Reading")
                        .font(SpineTokens.Typography.headline)
                    Image(systemName: step == .genres ? "arrow.right" : "book.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpineTokens.Spacing.md)
                .background(canContinue ? SpineTokens.Colors.accentGold : SpineTokens.Colors.warmStone)
                .foregroundColor(.white)
                .cornerRadius(SpineTokens.Radius.medium)
            }
            .disabled(!canContinue)
            .padding(.horizontal, SpineTokens.Spacing.lg)
            .padding(.bottom, SpineTokens.Spacing.xl)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
    }
    
    // MARK: - Step 1: Genres
    
    private var genresStep: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                Text("What do you enjoy\nreading?")
                    .font(SpineTokens.Typography.largeTitle)
                    .foregroundColor(SpineTokens.Colors.ink)
                
                Text("Pick at least 2 genres.")
                    .font(SpineTokens.Typography.callout)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            
            FlowLayout(spacing: SpineTokens.Spacing.xs) {
                ForEach(Self.genres, id: \.self) { genre in
                    ChipButton(
                        label: genre,
                        isSelected: selectedGenres.contains(genre)
                    ) {
                        toggleGenre(genre)
                    }
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
        }
    }
    
    // MARK: - Step 2: Vibes
    
    private var vibesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                    Text("What keeps you\nreading?")
                        .font(SpineTokens.Typography.largeTitle)
                        .foregroundColor(SpineTokens.Colors.ink)
                    
                    Text("Select vibes you enjoy in books.")
                        .font(SpineTokens.Typography.callout)
                        .foregroundColor(SpineTokens.Colors.subtleGray)
                }
                
                FlowLayout(spacing: SpineTokens.Spacing.xs) {
                    ForEach(Self.positiveVibes, id: \.self) { vibe in
                        ChipButton(
                            label: vibe,
                            isSelected: selectedVibes.contains(vibe)
                        ) {
                            toggleVibe(vibe)
                        }
                    }
                }
                
                // Optional avoided vibes
                Button {
                    withAnimation(SpineTokens.Animation.standard) {
                        showAvoidedSection.toggle()
                    }
                } label: {
                    HStack {
                        Text("Any turn-offs?")
                            .font(SpineTokens.Typography.caption)
                            .foregroundColor(SpineTokens.Colors.subtleGray)
                        Image(systemName: showAvoidedSection ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(SpineTokens.Colors.subtleGray)
                    }
                }
                
                if showAvoidedSection {
                    FlowLayout(spacing: SpineTokens.Spacing.xs) {
                        ForEach(Self.negativeVibes, id: \.self) { vibe in
                            ChipButton(
                                label: vibe,
                                isSelected: avoidedVibes.contains(vibe),
                                style: .negative
                            ) {
                                toggleAvoidedVibe(vibe)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
        }
    }
    
    // MARK: - Logic
    
    private var canContinue: Bool {
        switch step {
        case .genres: return selectedGenres.count >= 2
        case .vibes: return selectedVibes.count >= 1
        }
    }
    
    private func toggleGenre(_ genre: String) {
        withAnimation(SpineTokens.Animation.quick) {
            if selectedGenres.contains(genre) {
                selectedGenres.remove(genre)
            } else {
                selectedGenres.insert(genre)
            }
        }
    }
    
    private func toggleVibe(_ vibe: String) {
        withAnimation(SpineTokens.Animation.quick) {
            if selectedVibes.contains(vibe) {
                selectedVibes.remove(vibe)
            } else {
                selectedVibes.insert(vibe)
            }
        }
    }
    
    private func toggleAvoidedVibe(_ vibe: String) {
        withAnimation(SpineTokens.Animation.quick) {
            if avoidedVibes.contains(vibe) {
                avoidedVibes.remove(vibe)
            } else {
                avoidedVibes.insert(vibe)
            }
        }
    }
    
    private func handleContinue() {
        switch step {
        case .genres:
            withAnimation(SpineTokens.Animation.standard) {
                step = .vibes
            }
        case .vibes:
            saveTasteProfile()
            onComplete()
        }
    }
    
    private func saveTasteProfile() {
        let profile = UserTasteProfile()
        profile.setOnboardingGenres(Array(selectedGenres))
        profile.setOnboardingVibes(liked: Array(selectedVibes), avoided: Array(avoidedVibes))
        profile.hasCompletedTasteOnboarding = true
        modelContext.insert(profile)
        try? modelContext.save()
        
        AnalyticsService.shared.log(.onboardingCompleted, properties: [
            "genres": selectedGenres.joined(separator: ", "),
            "vibes": selectedVibes.joined(separator: ", "),
            "avoided": avoidedVibes.joined(separator: ", ")
        ])
    }
}

// MARK: - Chip Button

struct ChipButton: View {
    let label: String
    let isSelected: Bool
    var style: ChipStyle = .positive
    let action: () -> Void
    
    enum ChipStyle {
        case positive, negative
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SpineTokens.Typography.callout)
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.vertical, SpineTokens.Spacing.sm)
                .background(chipBackground)
                .foregroundColor(chipForeground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(chipBorder, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(SpineTokens.Animation.quick, value: isSelected)
    }
    
    private var chipBackground: Color {
        if !isSelected { return SpineTokens.Colors.cream }
        switch style {
        case .positive: return SpineTokens.Colors.accentGold.opacity(0.15)
        case .negative: return SpineTokens.Colors.streakFlame.opacity(0.1)
        }
    }
    
    private var chipForeground: Color {
        if !isSelected { return SpineTokens.Colors.charcoal }
        switch style {
        case .positive: return SpineTokens.Colors.espresso
        case .negative: return SpineTokens.Colors.streakFlame
        }
    }
    
    private var chipBorder: Color {
        if !isSelected { return SpineTokens.Colors.warmStone }
        switch style {
        case .positive: return SpineTokens.Colors.accentGold
        case .negative: return SpineTokens.Colors.streakFlame.opacity(0.5)
        }
    }
}

// MARK: - Flow Layout
// Wrapping horizontal layout for chips.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, containerWidth: proposal.width ?? .infinity)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > containerWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
