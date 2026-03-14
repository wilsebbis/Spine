import SwiftUI

// MARK: - XP Toast / Reward Burst Card
// Duolingo-style post-completion reward card.
// Shows XP earned, streak status, optional quick verdict, and CTAs.
// Designed to display for 1.5–3 seconds unless user interacts.

struct XPToast: View {
    let reward: XPReward
    let currentStreak: Int
    @Binding var isPresented: Bool
    var onContinue: (() -> Void)?
    
    @State private var slideIn = false
    @State private var xpCountUp = 0
    @State private var selectedVerdict: ReadingVerdict?
    
    var body: some View {
        VStack {
            if slideIn {
                VStack(spacing: SpineTokens.Spacing.md) {
                    // Unit Complete header
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(SpineTokens.Colors.successGreen)
                        Text("Unit Complete!")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Spacer()
                    }
                    
                    // XP earned row with count-up animation
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
                                .frame(width: 48, height: 48)
                            
                            Text("+\(xpCountUp)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("+\(reward.totalXP) XP earned!")
                                .font(SpineTokens.Typography.headline)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            
                            // Bonus breakdown
                            HStack(spacing: SpineTokens.Spacing.xs) {
                                if reward.streakBonus > 0 {
                                    bonusPill("🔥 +\(reward.streakBonus)")
                                }
                                if reward.speedBonus > 0 {
                                    bonusPill("💨 +\(reward.speedBonus)")
                                }
                                if reward.firstOfDayBonus > 0 {
                                    bonusPill("☀️ +\(reward.firstOfDayBonus)")
                                }
                                if reward.bookFinishBonus > 0 {
                                    bonusPill("📖 +\(reward.bookFinishBonus)")
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Streak status
                    if currentStreak > 0 {
                        HStack(spacing: SpineTokens.Spacing.xs) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(SpineTokens.Colors.streakFlame)
                            Text("\(currentStreak) day streak!")
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            
                            if currentStreak == 7 || currentStreak == 30 || currentStreak == 100 {
                                Text("🎉")
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                        .background(SpineTokens.Colors.streakFlame.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                    }
                    
                    // Quick verdict (single-tap, max one)
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("How was it?")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: SpineTokens.Spacing.xxs) {
                                ForEach([
                                    ReadingVerdict.worthIt,
                                    .gladIReadIt,
                                    .hardButRewarding,
                                    .notForMe
                                ], id: \.self) { verdict in
                                    quickVerdictChip(verdict)
                                }
                            }
                        }
                    }
                    
                    // CTAs
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        Button {
                            dismissToast()
                        } label: {
                            Text("Stop here")
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SpineTokens.Spacing.sm)
                                .background(SpineTokens.Colors.warmStone.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                        
                        Button {
                            dismissToast()
                            onContinue?()
                        } label: {
                            Text("Continue →")
                                .font(SpineTokens.Typography.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SpineTokens.Spacing.sm)
                                .background(
                                    LinearGradient(
                                        colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                    }
                }
                .padding(SpineTokens.Spacing.lg)
                .background(SpineTokens.Colors.cream)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
                .shadow(color: SpineTokens.Colors.accentGold.opacity(0.25), radius: 16, y: 6)
                .padding(.horizontal, SpineTokens.Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, SpineTokens.Spacing.xxl)
        .background(
            slideIn ? Color.black.opacity(0.3) : Color.clear
        )
        .animation(.easeInOut(duration: 0.3), value: slideIn)
        .onTapGesture { } // prevent taps from passing through
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                slideIn = true
            }
            // Count-up animation for XP
            animateXPCountUp()
        }
    }
    
    // MARK: - Components
    
    private func bonusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(SpineTokens.Colors.espresso)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SpineTokens.Colors.softGold)
            .clipShape(Capsule())
    }
    
    private func quickVerdictChip(_ verdict: ReadingVerdict) -> some View {
        let isSelected = selectedVerdict == verdict
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedVerdict = isSelected ? nil : verdict
            }
        } label: {
            Text("\(verdict.emoji) \(verdict.rawValue)")
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(isSelected ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)
                .padding(.horizontal, SpineTokens.Spacing.sm)
                .padding(.vertical, SpineTokens.Spacing.xs)
                .background(
                    isSelected
                        ? SpineTokens.Colors.accentGold.opacity(0.2)
                        : SpineTokens.Colors.warmStone.opacity(0.15)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? SpineTokens.Colors.accentGold : .clear, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Logic
    
    private func animateXPCountUp() {
        let target = reward.totalXP
        let steps = min(target, 20)
        guard steps > 0 else { return }
        let interval = 0.8 / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    xpCountUp = (target * i) / steps
                }
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
