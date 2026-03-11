import SwiftUI

// MARK: - Liquid Glass Components for iOS 26
// These use the native glassEffect() API introduced in iOS 26.

/// A card with Liquid Glass material applied.
/// Used for Today screen cards, library items, and profile stats.
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    
    init(
        cornerRadius: CGFloat = SpineTokens.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// A prominent CTA button with Liquid Glass styling.
struct SpineGlassButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SpineTokens.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(SpineTokens.Typography.headline)
            }
            .foregroundStyle(SpineTokens.Colors.espresso)
            .padding(.horizontal, SpineTokens.Spacing.lg)
            .padding(.vertical, SpineTokens.Spacing.sm)
        }
        .buttonStyle(.glass)
    }
}

/// A circular progress ring used for daily reading progress.
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let gradient: [Color]
    
    init(
        progress: Double,
        lineWidth: CGFloat = 6,
        size: CGFloat = 100,
        gradient: [Color] = [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber]
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.size = size
        self.gradient = gradient
    }
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    SpineTokens.Colors.warmStone.opacity(0.3),
                    lineWidth: lineWidth
                )
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradient),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(SpineTokens.Animation.gentle, value: progress)
        }
        .frame(width: size, height: size)
    }
}

/// Streak badge with flame icon and count.
struct StreakBadge: View {
    let count: Int
    let isActive: Bool
    
    init(count: Int, isActive: Bool = true) {
        self.count = count
        self.isActive = isActive
    }
    
    var body: some View {
        HStack(spacing: SpineTokens.Spacing.xxs) {
            Image(systemName: isActive ? "flame.fill" : "flame")
                .foregroundStyle(
                    isActive ? SpineTokens.Colors.streakFlame : SpineTokens.Colors.subtleGray
                )
                .font(.body.weight(.semibold))
            
            Text("\(count)")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(
                    isActive ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray
                )
            
            Text(count == 1 ? "day" : "days")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .padding(.horizontal, SpineTokens.Spacing.sm)
        .padding(.vertical, SpineTokens.Spacing.xs)
        .glassEffect(.regular, in: Capsule())
    }
}

/// A reading calendar heatmap showing daily reading activity.
struct ReadingCalendar: View {
    let sessions: [Date: Bool]
    let weeksToShow: Int
    
    private let calendar = Calendar.current
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    
    init(sessions: [Date: Bool] = [:], weeksToShow: Int = 12) {
        self.sessions = sessions
        self.weeksToShow = weeksToShow
    }
    
    var body: some View {
        let weeks = generateWeeks()
        
        HStack(spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: cellSpacing) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let isActive = sessions[calendar.startOfDay(for: day)] ?? false
                            let isToday = calendar.isDateInToday(day)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(isActive: isActive, isToday: isToday))
                                .frame(width: cellSize, height: cellSize)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }
    
    private func cellColor(isActive: Bool, isToday: Bool) -> Color {
        if isToday && isActive {
            return SpineTokens.Colors.accentGold
        } else if isActive {
            return SpineTokens.Colors.accentGold.opacity(0.6)
        } else if isToday {
            return SpineTokens.Colors.warmStone.opacity(0.6)
        } else {
            return SpineTokens.Colors.warmStone.opacity(0.2)
        }
    }
    
    private func generateWeeks() -> [[Date?]] {
        let today = Date()
        let totalDays = weeksToShow * 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -totalDays + 1, to: today) else {
            return []
        }
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []
        
        // Pad the first week
        let startWeekday = calendar.component(.weekday, from: startDate)
        for _ in 1..<startWeekday {
            currentWeek.append(nil)
        }
        
        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            currentWeek.append(date)
            
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
}

// MARK: - Book Cover Placeholder

/// Generates a beautiful placeholder cover for books without cover art.
struct BookCoverPlaceholder: View {
    let title: String
    let author: String
    let size: CGSize
    
    private var gradientColors: [Color] {
        // Deterministic gradient based on title hash
        let hash = abs(title.hashValue)
        let palettes: [[Color]] = [
            [Color(hex: "2C3E50"), Color(hex: "3498DB")],
            [Color(hex: "4A3728"), Color(hex: "C49B5C")],
            [Color(hex: "2D1B30"), Color(hex: "8E4585")],
            [Color(hex: "1A3A2A"), Color(hex: "4CAF82")],
            [Color(hex: "3D2B1F"), Color(hex: "D4A853")],
            [Color(hex: "1C2833"), Color(hex: "5DADE2")],
        ]
        return palettes[hash % palettes.count]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: SpineTokens.Spacing.xs) {
                Spacer()
                
                Text(title)
                    .font(.system(size: size.width * 0.1, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, SpineTokens.Spacing.sm)
                
                Rectangle()
                    .fill(.white.opacity(0.4))
                    .frame(width: size.width * 0.4, height: 1)
                
                Text(author)
                    .font(.system(size: size.width * 0.06, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                
                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
    }
}

// MARK: - Stat Card

/// A glassmorphic stat card for Profile screen.
struct StatCard: View {
    let value: String
    let label: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(SpineTokens.Colors.accentGold)
            
            Text(value)
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text(label)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .frame(maxWidth: .infinity)
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
}
