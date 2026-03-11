import SwiftUI

// MARK: - XP Progress Bar
// Duolingo-style horizontal bar showing progress to next level.

struct XPProgressBar: View {
    let currentXP: Int
    let levelXP: Int       // XP at start of current level
    let nextLevelXP: Int   // XP required for next level
    let level: Int
    let title: String
    
    @State private var animatedProgress: Double = 0
    
    private var progress: Double {
        guard nextLevelXP > levelXP else { return 1.0 }
        return Double(currentXP - levelXP) / Double(nextLevelXP - levelXP)
    }
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Level + title
            HStack {
                // Level badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("\(level)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.espresso)
                
                Spacer()
                
                Text("\(currentXP - levelXP) / \(nextLevelXP - levelXP) XP")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(SpineTokens.Colors.warmStone.opacity(0.3))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * animatedProgress))
                    
                    // Shine effect
                    if animatedProgress > 0.05 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(0, geo.size.width * animatedProgress), height: 5)
                    }
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: currentXP) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Daily XP Ring
// Circular progress showing daily XP goal completion.

struct DailyXPRing: View {
    let dailyXP: Int
    let goal: Int
    
    @State private var animatedProgress: Double = 0
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(dailyXP) / Double(goal))
    }
    
    private var isComplete: Bool { dailyXP >= goal }
    
    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(SpineTokens.Colors.warmStone.opacity(0.3), lineWidth: 6)
            
            // Progress
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: isComplete
                            ? [SpineTokens.Colors.successGreen, SpineTokens.Colors.successGreen]
                            : [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Center content
            VStack(spacing: 0) {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(SpineTokens.Colors.successGreen)
                } else {
                    Text("\(dailyXP)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(SpineTokens.Colors.espresso)
                    Text("/\(goal)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(SpineTokens.Colors.subtleGray)
                }
            }
        }
        .frame(width: 60, height: 60)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: dailyXP) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = progress
            }
        }
    }
}
