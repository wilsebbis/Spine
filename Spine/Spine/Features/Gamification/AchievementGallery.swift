import SwiftUI

// MARK: - Achievement Gallery
// Grid of achievement badges — locked badges greyed out, unlocked in full color.

struct AchievementGallery: View {
    let unlockedIDs: Set<String>
    let dates: [String: Date]
    
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: SpineTokens.Spacing.sm)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Achievements")
                .font(SpineTokens.Typography.headline)
                .foregroundColor(SpineTokens.Colors.espresso)
            
            // Progress count
            let total = AchievementEngine.all.count
            let unlocked = unlockedIDs.count
            HStack(spacing: SpineTokens.Spacing.xxs) {
                Text("\(unlocked)/\(total)")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.accentGold)
                Text("unlocked")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundColor(SpineTokens.Colors.subtleGray)
            }
            
            // Badge grid
            LazyVGrid(columns: columns, spacing: SpineTokens.Spacing.md) {
                ForEach(AchievementEngine.all) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        isUnlocked: unlockedIDs.contains(achievement.id),
                        unlockDate: dates[achievement.id]
                    )
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let unlockDate: Date?
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                            ? LinearGradient(
                                colors: [SpineTokens.Colors.accentGold.opacity(0.2), SpineTokens.Colors.accentAmber.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [SpineTokens.Colors.warmStone.opacity(0.2), SpineTokens.Colors.warmStone.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(
                        isUnlocked ? SpineTokens.Colors.accentGold : SpineTokens.Colors.warmStone
                    )
            }
            
            Text(achievement.name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isUnlocked ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)
                .lineLimit(1)
            
            if let date = unlockDate {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(SpineTokens.Colors.subtleGray)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}
