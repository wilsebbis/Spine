import SwiftUI

// MARK: - Audio Mini Player View
// Compact bottom bar (~60pt) for persistent audiobook playback while reading.
// Shows chapter title, play/pause, ±15s skip, and a thin progress line.
// Tap the bar to expand into full AudiobookPlayerView.

struct AudioMiniPlayerView: View {
    
    let book: Book
    let player: AudioPlaybackEngine
    let currentChapterTitle: String
    let onExpand: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Thin progress line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(SpineTokens.Colors.warmStone.opacity(0.3))
                    
                    Rectangle()
                        .fill(SpineTokens.Colors.accentGold)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 3)
            
            // Controls bar
            HStack(spacing: SpineTokens.Spacing.sm) {
                // Headphones icon
                Image(systemName: "headphones")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                // Chapter title — tap expands
                VStack(alignment: .leading, spacing: 1) {
                    Text(currentChapterTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .lineLimit(1)
                    
                    Text(formatTime(player.currentTime) + " / " + formatTime(player.duration))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onExpand()
                }
                
                // Skip back 15s
                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
                .buttonStyle(.plain)
                
                // Play/Pause
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                // Skip forward 15s
                Button {
                    player.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
                .buttonStyle(.plain)
                
                // Dismiss mini player
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.vertical, SpineTokens.Spacing.sm)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
    }
    
    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
