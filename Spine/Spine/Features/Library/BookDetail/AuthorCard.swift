import SwiftUI

// MARK: - Author Card
// Displays author biographical information with lifespan and notable works.

struct AuthorCard: View {
    let metadata: AuthorMetadata
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
            // Header
            HStack(spacing: SpineTokens.Spacing.sm) {
                // Author initial circle
                ZStack {
                    Circle()
                        .fill(SpineTokens.Colors.accentGold.opacity(0.15))
                    Text(String(metadata.name.prefix(1)))
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                    Text(metadata.name)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        if let lifespan = metadata.lifespanText {
                            Text(lifespan)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                        
                        if let nationality = metadata.nationality {
                            Text("·")
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                            Text(nationality)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Bio
            Text(metadata.shortBio)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.85))
                .lineLimit(isExpanded ? nil : 3)
            
            if metadata.shortBio.count > 120 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show Less" : "Read More")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            
            // Notable Works
            if !metadata.notableWorks.isEmpty {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                    Text("Notable Works")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    
                    SpineFlowLayout(spacing: SpineTokens.Spacing.xxs) {
                        ForEach(metadata.notableWorks, id: \.self) { work in
                            Text(work)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .padding(.horizontal, SpineTokens.Spacing.xs)
                                .padding(.vertical, SpineTokens.Spacing.xxxs)
                                .background(SpineTokens.Colors.warmStone.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
}

