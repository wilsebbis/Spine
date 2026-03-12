import SwiftUI
import SwiftData

// MARK: - Micro Reason Sheet
// Presented periodically after reading units to capture granular feedback.
// Writes liked/disliked reasons to BookInteraction for recommendation tuning.

struct MicroReasonSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    @State private var selectedLiked: Set<String> = []
    @State private var selectedDisliked: Set<String> = []
    
    static let likedOptions = [
        "Prose", "Characters", "Plot", "Ideas",
        "Atmosphere", "Pacing", "Humor", "Emotion"
    ]
    
    static let dislikedOptions = [
        "Slow", "Dense", "Confusing",
        "Predictable", "Flat characters", "Dry"
    ]
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            // Handle
            Capsule()
                .fill(SpineTokens.Colors.warmStone)
                .frame(width: 36, height: 4)
                .padding(.top, SpineTokens.Spacing.sm)
            
            // Header
            VStack(spacing: SpineTokens.Spacing.xxs) {
                Text("What stood out?")
                    .font(SpineTokens.Typography.title)
                    .foregroundColor(SpineTokens.Colors.ink)
                
                Text(book.title)
                    .font(SpineTokens.Typography.caption)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
                    .lineLimit(1)
            }
            
            // Liked reasons
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                Text("Enjoyed")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
                    .textCase(.uppercase)
                
                SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                    ForEach(Self.likedOptions, id: \.self) { reason in
                        ChipButton(
                            label: reason,
                            isSelected: selectedLiked.contains(reason)
                        ) {
                            toggleLiked(reason)
                        }
                    }
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            
            // Disliked reasons (optional)
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                Text("Less so")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
                    .textCase(.uppercase)
                
                SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                    ForEach(Self.dislikedOptions, id: \.self) { reason in
                        ChipButton(
                            label: reason,
                            isSelected: selectedDisliked.contains(reason),
                            style: .negative
                        ) {
                            toggleDisliked(reason)
                        }
                    }
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            
            Spacer()
            
            // Submit
            HStack(spacing: SpineTokens.Spacing.md) {
                Button("Skip") {
                    dismiss()
                }
                .font(SpineTokens.Typography.callout)
                .foregroundColor(SpineTokens.Colors.subtleGray)
                
                Button {
                    saveReasons()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(SpineTokens.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.accentGold)
                        .foregroundColor(.white)
                        .cornerRadius(SpineTokens.Radius.medium)
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            .padding(.bottom, SpineTokens.Spacing.lg)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Logic
    
    private func toggleLiked(_ reason: String) {
        withAnimation(SpineTokens.Animation.quick) {
            if selectedLiked.contains(reason) {
                selectedLiked.remove(reason)
            } else {
                selectedLiked.insert(reason)
            }
        }
    }
    
    private func toggleDisliked(_ reason: String) {
        withAnimation(SpineTokens.Animation.quick) {
            if selectedDisliked.contains(reason) {
                selectedDisliked.remove(reason)
            } else {
                selectedDisliked.insert(reason)
            }
        }
    }
    
    private func saveReasons() {
        let interaction = BookInteraction(
            interactionType: .reviewed,
            book: book,
            likedReasons: Array(selectedLiked),
            dislikedReasons: Array(selectedDisliked)
        )
        modelContext.insert(interaction)
        
        // Also update taste profile
        let descriptor = FetchDescriptor<UserTasteProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            for reason in selectedLiked {
                profile.reinforceVibe(reason.lowercased())
            }
            for reason in selectedDisliked {
                profile.penalizeVibe(reason.lowercased())
            }
        }
        
        try? modelContext.save()
        
        AnalyticsService.shared.log(.reactionSaved, properties: [
            "bookTitle": book.title,
            "liked": selectedLiked.joined(separator: ", "),
            "disliked": selectedDisliked.joined(separator: ", ")
        ])
    }
}
