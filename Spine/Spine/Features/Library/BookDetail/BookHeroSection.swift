import SwiftUI

// MARK: - Book Hero Section
// Apple Books-style hero with cover, title, metadata, and CTA.

struct BookHeroSection: View {
    let book: Book
    let onStartReading: () -> Void
    
    private var progressState: ProgressState {
        guard let progress = book.readingProgress else { return .start }
        if progress.isFinished { return .finished }
        if progress.completedPercent > 0 { return .inProgress(progress.completedPercent) }
        return .start
    }
    
    private enum ProgressState {
        case start
        case inProgress(Double)
        case finished
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: SpineTokens.Spacing.lg) {
            // Cover
            coverImage
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            
            // Info stack
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                Text(book.title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(3)
                
                Text(book.author)
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                // Literary period badge
                if let period = book.literaryPeriod {
                    Text(period)
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                        .padding(.horizontal, SpineTokens.Spacing.xs)
                        .padding(.vertical, SpineTokens.Spacing.xxxs)
                        .background(SpineTokens.Colors.accentGold.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Metadata row
                metadataRow
                
                Spacer(minLength: 0)
                
                // CTA
                ctaButton
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
        .padding(.vertical, SpineTokens.Spacing.lg)
    }
    
    // MARK: - Cover
    
    @ViewBuilder
    private var coverImage: some View {
        if let coverData = book.coverImageData,
           let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
        } else {
            BookCoverPlaceholder(
                title: book.title,
                author: book.author,
                size: CGSize(width: 140, height: 210)
            )
        }
    }
    
    // MARK: - Metadata Row
    
    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
            if let year = book.publicationYear {
                metadataItem(icon: "calendar", text: "\(year)")
            }
            
            if book.totalWordCount > 0 {
                let hours = book.estimatedHours
                let label = hours < 1 ? String(format: "%.0f min", hours * 60) : String(format: "%.1f hrs", hours)
                metadataItem(icon: "clock", text: label)
            }
            
            if book.unitCount > 0 {
                metadataItem(icon: "text.page", text: "\(book.unitCount) units")
            }
        }
    }
    
    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: SpineTokens.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
            Text(text)
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button(action: onStartReading) {
            HStack(spacing: SpineTokens.Spacing.xs) {
                Image(systemName: ctaIcon)
                    .font(.body.weight(.semibold))
                Text(ctaTitle)
                    .font(SpineTokens.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpineTokens.Spacing.sm)
            .background(SpineTokens.Colors.accentGold.gradient)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
    }
    
    private var ctaTitle: String {
        switch progressState {
        case .start: return "Start Reading"
        case .inProgress(let pct): return "Continue · \(Int(pct * 100))%"
        case .finished: return "Read Again"
        }
    }
    
    private var ctaIcon: String {
        switch progressState {
        case .start: return "book.fill"
        case .inProgress: return "arrow.right"
        case .finished: return "arrow.counterclockwise"
        }
    }
}
