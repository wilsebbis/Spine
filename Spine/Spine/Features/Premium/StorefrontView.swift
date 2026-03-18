import SwiftUI
import SwiftData

// MARK: - Storefront View
// Virtual Economy storefront where users can spend their earned Pages
// on Daily Passes, or upgrade to Premium.

struct StorefrontView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var xpProfiles: [XPProfile]
    
    @State private var showPaywall = false
    @State private var showToast = false
    @State private var animationAmount = 1.0
    
    private var profile: XPProfile? { xpProfiles.first }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SpineTokens.Colors.warmStone
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: SpineTokens.Spacing.xl) {
                        
                        // Header: Current Balance
                        VStack(spacing: SpineTokens.Spacing.sm) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                                .scaleEffect(animationAmount)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(1), value: animationAmount)
                            
                            Text("\(profile?.pages ?? 0)")
                                .font(SpineTokens.Typography.display)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            
                            Text("Your Pages Balance")
                                .font(SpineTokens.Typography.subheadline)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.xl)
                        
                        // Daily Pass Purchase Card
                        VStack(spacing: SpineTokens.Spacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Daily Pass")
                                        .font(SpineTokens.Typography.headline)
                                        .foregroundStyle(SpineTokens.Colors.espresso)
                                    Text("Unlock 1 additional reading unit today.")
                                        .font(SpineTokens.Typography.caption)
                                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "ticket.fill")
                                    .font(.title2)
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                            }
                            
                            Button {
                                buyPass()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Buy for \(EconomyService.shared.dailyPassCost)")
                                    Image(systemName: "book.pages")
                                }
                                .font(SpineTokens.Typography.button)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    (profile?.pages ?? 0) >= EconomyService.shared.dailyPassCost
                                        ? SpineTokens.Colors.accentGold
                                        : SpineTokens.Colors.subtleGray
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                            }
                            .disabled((profile?.pages ?? 0) < EconomyService.shared.dailyPassCost)
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                        
                        // Premium Banner
                        if !PremiumManager.shared.isPremium {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upgrade to Premium")
                                            .font(SpineTokens.Typography.headline)
                                            .foregroundStyle(.white)
                                        Text("Unlimited daily reading units, no passes required.")
                                            .font(SpineTokens.Typography.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [SpineTokens.Colors.espresso, SpineTokens.Colors.accentGold.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text("Daily Pass Unlocked! 🎟️")
                        .font(SpineTokens.Typography.body.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(SpineTokens.Colors.successGreen)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func buyPass() {
        guard let profile = profile else { return }
        if EconomyService.shared.buyDailyPass(profile: profile) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            animationAmount = 1.2
            
            withAnimation {
                showToast = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showToast = false }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animationAmount = 1.0 // Return to normal size
            }
        }
    }
}
