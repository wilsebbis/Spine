import SwiftUI

// MARK: - Karaoke Text View
// Apple Music-style word highlighting that follows audio playback.
// Ported from the web's CSS gradient fill approach:
//   Web: background-clip: text + linear-gradient(spoken_color var(--fill), upcoming_color)
//   iOS: AttributedString with per-word foreground color
//
// Three word states (matching web CSS classes):
//   .spoken  → full accent color (past words)
//   .current → highlighted with emphasis (active word)
//   .upcoming → muted color (future words)

struct KaraokeTextView: View {
    let timings: ChapterTimings
    let currentTime: Double
    let onWordTap: (TimedWord) -> Void
    
    // Active word index from binary search
    private var activeIndex: Int? {
        timings.activeWordIndex(at: currentTime)
    }
    
    // Active phrase for scroll anchoring
    private var activePhrase: TimedPhrase? {
        guard let idx = activeIndex else { return nil }
        return timings.phraseContaining(wordIndex: idx)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                    ForEach(timings.paragraphs) { phrase in
                        phraseView(phrase)
                            .id(phrase.start)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.vertical, SpineTokens.Spacing.lg)
            }
            .onChange(of: activePhrase?.start) { _, newPhraseStart in
                // Phrase-centered scrolling (not per-word, for smoothness)
                if let start = newPhraseStart {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(start, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Phrase Rendering
    
    @ViewBuilder
    private func phraseView(_ phrase: TimedPhrase) -> some View {
        let phraseWords = timings.words(in: phrase)
        let isActivePhrase = activePhrase?.start == phrase.start
        
        // Use a flow layout that wraps words naturally
        WrappingHStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
            ForEach(phraseWords) { word in
                wordView(word)
                    .onTapGesture {
                        onWordTap(word)
                    }
            }
        }
        .padding(SpineTokens.Spacing.xs)
        .background(
            isActivePhrase ?
            SpineTokens.Colors.accentGold.opacity(0.05) :
            Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        .animation(.easeInOut(duration: 0.2), value: isActivePhrase)
    }
    
    // MARK: - Word Rendering
    
    @ViewBuilder
    private func wordView(_ word: TimedWord) -> some View {
        let state = wordState(for: word)
        
        Text(word.w + " ")
            .font(SpineTokens.Typography.readerSerif(size: 18))
            .foregroundStyle(colorForState(state))
            .scaleEffect(state == .current ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: state)
    }
    
    // MARK: - Word State
    
    enum WordState: Equatable {
        case spoken     // past — fully highlighted
        case current    // active — prominent highlight
        case upcoming   // future — muted
    }
    
    private func wordState(for word: TimedWord) -> WordState {
        guard let active = activeIndex else {
            // No active word — everything is upcoming or spoken
            if currentTime > 0 && currentTime >= word.t1 {
                return .spoken
            }
            return .upcoming
        }
        
        if word.i < active {
            return .spoken
        } else if word.i == active {
            return .current
        } else {
            return .upcoming
        }
    }
    
    private func colorForState(_ state: WordState) -> Color {
        switch state {
        case .spoken:
            return SpineTokens.Colors.espresso
        case .current:
            return SpineTokens.Colors.accentGold
        case .upcoming:
            return SpineTokens.Colors.warmStone.opacity(0.4)
        }
    }
}

// MARK: - Wrapping HStack (Flow Layout)
// Lays out children in a horizontal flow that wraps to next line.

struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(
                    width: subview.sizeThatFits(.unspecified).width,
                    height: subview.sizeThatFits(.unspecified).height
                )
            )
        }
    }
    
    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && x > 0 {
                // Wrap to next line
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x)
        }
        
        return LayoutResult(
            size: CGSize(width: maxX, height: y + lineHeight),
            positions: positions
        )
    }
}

// MARK: - Audio Controls Bar

struct AudioControlsBar: View {
    @Bindable var engine: AudioPlaybackEngine
    let timings: ChapterTimings
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Scrubber
            ProgressView(value: engine.currentTime, total: max(engine.duration, 1))
                .tint(SpineTokens.Colors.accentGold)
            
            HStack {
                // Time
                Text(formatTime(engine.currentTime))
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .monospacedDigit()
                
                Spacer()
                
                // Speed control
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            engine.setRate(Float(rate))
                        } label: {
                            HStack {
                                Text("\(rate, specifier: "%.2g")×")
                                if abs(Double(engine.playbackRate) - rate) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(engine.playbackRate, specifier: "%.2g")×")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                        .padding(.horizontal, SpineTokens.Spacing.xs)
                        .padding(.vertical, SpineTokens.Spacing.xxxs)
                        .background(SpineTokens.Colors.accentGold.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Play/Pause
                Button {
                    engine.toggle()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                Spacer()
                
                // Skip back 15s
                Button {
                    engine.seek(to: max(0, engine.currentTime - 15))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.body)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
                
                // Skip forward 15s
                Button {
                    engine.seek(to: min(engine.duration, engine.currentTime + 15))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.body)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
                
                Spacer()
                
                // Remaining time
                Text("-\(formatTime(engine.duration - engine.currentTime))")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
        .padding(.vertical, SpineTokens.Spacing.sm)
        .background(.ultraThinMaterial)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
