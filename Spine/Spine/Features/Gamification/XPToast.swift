import SwiftUI

// MARK: - XP Toast
// Small notification that slides in after each unit completion.
// Shows XP gained with bonus breakdown. Requires tap to dismiss.

struct XPToast: View {
    let reward: XPReward
    @Binding var isPresented: Bool
    
    @State private var slideIn = false
    
    var body: some View {
        VStack {
            if slideIn {
                VStack(spacing: SpineTokens.Spacing.sm) {
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        // XP badge
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Text("+\(reward.totalXP)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("+\(reward.totalXP) XP earned!")
                                .font(SpineTokens.Typography.headline)
                                .foregroundColor(SpineTokens.Colors.espresso)
                            
                            if reward.wpm > 0 {
                                Text("\(Int(reward.wpm)) WPM")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundColor(SpineTokens.Colors.subtleGray)
                            }
                        }
                        
                        Spacer()
                        
                        // Bonus indicators
                        HStack(spacing: SpineTokens.Spacing.xxs) {
                            if reward.streakBonus > 0 { Text("🔥").font(.caption) }
                            if reward.speedBonus > 0 { Text("💨").font(.caption) }
                            if reward.firstOfDayBonus > 0 { Text("☀️").font(.caption) }
                        }
                    }
                }
                .padding(SpineTokens.Spacing.md)
                .background(SpineTokens.Colors.cream)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
                .shadow(color: SpineTokens.Colors.accentGold.opacity(0.3), radius: 10, y: 4)
                .padding(.horizontal, SpineTokens.Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    dismissToast()
                }
            }
            
            Spacer()
        }
        .padding(.top, SpineTokens.Spacing.xxl)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                slideIn = true
            }
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                dismissToast()
            }
        }
    }
    
    private func dismissToast() {
        guard slideIn else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            slideIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}
