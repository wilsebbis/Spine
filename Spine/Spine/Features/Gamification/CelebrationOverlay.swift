import SwiftUI

// MARK: - Celebration Overlay
// Full-screen celebration for level-ups and major achievements.
// Confetti, level badge with glow, XP counter, auto-dismiss.

struct CelebrationOverlay: View {
    let reward: XPReward
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showConfetti = false
    @State private var xpCounter = 0
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // Confetti layer
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: showConfetti ? particle.endY : particle.startY)
                    .rotationEffect(.degrees(showConfetti ? particle.rotation : 0))
                    .opacity(showConfetti ? 0 : 1)
            }
            
            // Content
            VStack(spacing: SpineTokens.Spacing.xl) {
                if reward.didLevelUp {
                    levelUpContent
                } else if !reward.newAchievements.isEmpty {
                    achievementContent
                }
                
                // XP breakdown
                VStack(spacing: SpineTokens.Spacing.xs) {
                    Text("+\(xpCounter) XP")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    ForEach(reward.breakdownLines, id: \.self) { line in
                        Text(line)
                            .font(SpineTokens.Typography.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .scaleEffect(showContent ? 1.0 : 0.3)
                .opacity(showContent ? 1 : 0)
                
                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(SpineTokens.Typography.headline)
                        .foregroundColor(SpineTokens.Colors.espresso)
                        .frame(width: 200)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.accentGold)
                        .clipShape(Capsule())
                }
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            generateConfetti()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            
            withAnimation(.easeOut(duration: 2.5)) {
                showConfetti = true
            }
            
            // Animate XP counter
            animateCounter()
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                onDismiss()
            }
        }
    }
    
    // MARK: - Level Up Content
    
    private var levelUpContent: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Glowing level badge
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SpineTokens.Colors.accentGold.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text("\(reward.newLevel)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: SpineTokens.Colors.accentGold.opacity(0.5), radius: 20)
            }
            .scaleEffect(showContent ? 1.0 : 0.1)
            
            Text("LEVEL UP!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(4)
            
            Text(XPLevelTable.title(for: reward.newLevel))
                .font(SpineTokens.Typography.title3)
                .foregroundColor(SpineTokens.Colors.accentGold)
        }
    }
    
    // MARK: - Achievement Content
    
    private var achievementContent: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            if let first = reward.newAchievements.first {
                ZStack {
                    Circle()
                        .fill(SpineTokens.Colors.accentGold.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: first.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                .scaleEffect(showContent ? 1.0 : 0.1)
                
                Text("Achievement Unlocked!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(first.name)
                    .font(SpineTokens.Typography.title)
                    .foregroundColor(SpineTokens.Colors.accentGold)
                
                Text(first.description)
                    .font(SpineTokens.Typography.callout)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Confetti
    
    private func generateConfetti() {
        let colors: [Color] = [
            SpineTokens.Colors.accentGold,
            SpineTokens.Colors.accentAmber,
            SpineTokens.Colors.streakFlame,
            SpineTokens.Colors.successGreen,
            .white,
            .yellow,
        ]
        
        particles = (0..<60).map { i in
            ConfettiParticle(
                id: i,
                x: CGFloat.random(in: -200...200),
                startY: CGFloat.random(in: -400 ... -200),
                endY: CGFloat.random(in: 400...800),
                size: CGFloat.random(in: 4...10),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...720)
            )
        }
    }
    
    private func animateCounter() {
        let target = reward.totalXP
        let steps = min(target, 20)
        let interval = 0.8 / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                xpCounter = target * i / steps
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let color: Color
    let rotation: Double
}
