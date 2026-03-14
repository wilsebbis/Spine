import SwiftUI

// MARK: - Paywall View
// Premium comparison screen.
// Emphasizes what premium gives beyond text access:
// unlimited lessons, better scaffolding, audio, shields, AI.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var premium = PremiumManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Hero
                    heroSection
                    
                    // Feature comparison
                    comparisonCard
                    
                    // CTA
                    ctaSection
                    
                    // Restore
                    Button("Restore Purchases") {
                        premium.restorePurchases()
                    }
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    
                    // Legal
                    Text("Cancel anytime. No commitment.")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
            }
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            ZStack {
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
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Spine Premium")
                .font(SpineTokens.Typography.largeTitle)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Everything you need to actually finish the classics.")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, SpineTokens.Spacing.lg)
    }
    
    // MARK: - Comparison
    
    private var comparisonCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer().frame(width: 140)
                Text("Free")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .frame(width: 60)
                Text("Premium")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                    .frame(width: 70)
            }
            .padding(.vertical, SpineTokens.Spacing.sm)
            
            Divider()
            
            featureRow("Daily Lessons", free: "1 / day", premium: "Unlimited")
            featureRow("Reading Paths", free: "2 paths", premium: "All paths")
            featureRow("Streak Shields", free: "1 shield", premium: "2 shields")
            featureRow("Vocabulary Review", free: "10 words", premium: "Unlimited")
            featureRow("AI Companion", free: "Basic", premium: "Full access")
            featureRow("Audio Read-Along", free: "—", premium: "✓")
            featureRow("Offline Reading", free: "—", premium: "✓")
            featureRow("Saved Quotes", free: "10", premium: "Unlimited")
            featureRow("Ads", free: "Between sessions", premium: "None")
        }
        .padding(SpineTokens.Spacing.sm)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
    
    private func featureRow(_ feature: String, free: String, premium: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .frame(width: 140, alignment: .leading)
                
                Text(free)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .frame(width: 60)
                
                Text(premium)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                    .frame(width: 70)
            }
            .padding(.vertical, 8)
            
            Divider()
        }
    }
    
    // MARK: - CTA
    
    private var ctaSection: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            // Annual plan
            Button {
                premium.purchase()
                dismiss()
            } label: {
                VStack(spacing: 2) {
                    Text("Start 14-Day Free Trial")
                        .font(SpineTokens.Typography.headline)
                    Text("Then $4.99/month • Cancel anytime")
                        .font(SpineTokens.Typography.caption2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpineTokens.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            
            // Gift option
            Button {
                // TODO: Gift flow
            } label: {
                Label("Gift Premium to a Friend", systemImage: "gift.fill")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
        }
    }
}
