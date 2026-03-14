import SwiftUI
import SwiftData

// MARK: - Audiobook Player View
// Full-screen audiobook player with sequential chapter playback,
// progress tracking, and XP integration.

struct AudiobookPlayerView: View {
    let book: Book
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var player = AudioPlaybackEngine()
    @State private var currentChapterIndex = 0
    @State private var showChapterList = false
    @State private var showSpeedPicker = false
    @State private var showSleepTimer = false
    @State private var sleepTimerMinutes: Int? = nil
    @State private var sleepTimerEnd: Date? = nil
    @State private var showChapterComplete = false
    @State private var showXPToast = false
    @State private var latestReward: XPReward?
    @State private var sessionStartTime = Date()
    @State private var epubDownloadService: DownloadService?
    
    private var sortedChapters: [AudiobookChapter] {
        book.sortedAudioChapters
    }
    
    private var currentChapter: AudiobookChapter? {
        guard currentChapterIndex < sortedChapters.count else { return nil }
        return sortedChapters[currentChapterIndex]
    }
    
    private var hasNextChapter: Bool {
        currentChapterIndex < sortedChapters.count - 1
    }
    
    private var hasPreviousChapter: Bool {
        currentChapterIndex > 0
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    SpineTokens.Colors.espresso,
                    SpineTokens.Colors.espresso.opacity(0.85),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                Spacer()
                
                // Cover art
                coverArt
                    .padding(.bottom, SpineTokens.Spacing.xl)
                
                // Chapter info
                chapterInfo
                    .padding(.bottom, SpineTokens.Spacing.lg)
                
                // Progress bar
                progressBar
                    .padding(.horizontal, SpineTokens.Spacing.xl)
                    .padding(.bottom, SpineTokens.Spacing.lg)
                
                // Transport controls
                transportControls
                    .padding(.bottom, SpineTokens.Spacing.lg)
                
                // Bottom controls (speed, sleep, chapters)
                bottomControls
                
                Spacer()
            }
            .padding(.horizontal, SpineTokens.Spacing.lg)
            
            // Chapter complete overlay
            if showChapterComplete {
                chapterCompleteOverlay
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            savePlaybackPosition()
            player.pause()
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .onChange(of: showXPToast) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showXPToast = false
                }
            }
        }
        .overlay(alignment: .top) {
            if showXPToast, let reward = latestReward {
                xpToast(reward: reward)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                savePlaybackPosition()
                player.pause()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Book icon (navigate to EPUB reader or download)
            epubBookButton
        }
        .padding(.top, SpineTokens.Spacing.md)
    }
    
    // MARK: - EPUB Book Button (3 states)
    
    @ViewBuilder
    private var epubBookButton: some View {
        let dlState = epubDownloadService?.activeDownloads[book.id]
        
        if book.isDownloaded {
            // State 1: EPUB available → open reader
            Button {
                savePlaybackPosition()
                player.pause()
                dismiss()
            } label: {
                Image(systemName: "book.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        } else if case .downloading(let progress) = dlState {
            // Downloading EPUB
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "book")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            }
        } else if case .ingesting = dlState {
            ProgressView()
                .tint(.white)
                .frame(width: 28, height: 28)
        } else if book.gutenbergId != nil && !book.gutenbergId!.isEmpty {
            // State 2: EPUB available in catalog → offer download
            Menu {
                Button {
                    if epubDownloadService == nil {
                        epubDownloadService = DownloadService(modelContext: modelContext)
                    }
                    Task {
                        await epubDownloadService?.download(book: book)
                    }
                } label: {
                    Label("Download EPUB", systemImage: "arrow.down.circle")
                }
            } label: {
                Image(systemName: "book.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            // No EPUB available
            Color.clear.frame(width: 28, height: 28)
        }
    }
    
    // MARK: - Cover Art
    
    private var coverArt: some View {
        Group {
            if let coverData = book.coverImageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SpineTokens.Colors.warmStone.opacity(0.3))
                    .frame(width: 260, height: 260)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "headphones")
                                .font(.system(size: 48))
                            Text(book.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
            }
        }
    }
    
    // MARK: - Chapter Info
    
    private var chapterInfo: some View {
        VStack(spacing: 4) {
            Text(currentChapter?.title ?? "Loading…")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text("Chapter \(currentChapterIndex + 1) of \(sortedChapters.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)
                    
                    // Progress
                    let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    Capsule()
                        .fill(SpineTokens.Colors.accentGold)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .frame(height: 4)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let ratio = max(0, min(1, value.location.x / geo.size.width))
                    player.seek(to: ratio * player.duration)
                })
            }
            .frame(height: 20)
            
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
                
                Spacer()
                
                Text("-\(formatTime(max(0, player.duration - player.currentTime)))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Transport Controls
    
    private var transportControls: some View {
        HStack(spacing: SpineTokens.Spacing.xl) {
            // Previous chapter
            Button {
                if hasPreviousChapter {
                    goToChapter(currentChapterIndex - 1)
                }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundStyle(hasPreviousChapter ? .white : .white.opacity(0.3))
            }
            .disabled(!hasPreviousChapter)
            
            // Skip back 15s
            Button {
                player.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            
            // Play/Pause
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
            
            // Skip forward 15s
            Button {
                player.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            
            // Next chapter
            Button {
                if hasNextChapter {
                    goToChapter(currentChapterIndex + 1)
                }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundStyle(hasNextChapter ? .white : .white.opacity(0.3))
            }
            .disabled(!hasNextChapter)
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: SpineTokens.Spacing.xl) {
            // Speed
            Button {
                cycleSpeed()
            } label: {
                Text(speedLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Chapter list
            Button {
                showChapterList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Sleep timer
            Button {
                cycleSleepTimer()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sleepTimerMinutes != nil ? "moon.fill" : "moon")
                        .font(.body)
                    if let mins = sleepTimerMinutes {
                        Text("\(mins)m")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Chapter List Sheet
    
    private var chapterListSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(sortedChapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        showChapterList = false
                        goToChapter(index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(.body)
                                    .foregroundStyle(
                                        index == currentChapterIndex ?
                                        SpineTokens.Colors.accentGold :
                                        SpineTokens.Colors.espresso
                                    )
                                
                                Text(formatTime(Double(chapter.durationSeconds)))
                                    .font(.caption)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                            }
                            
                            Spacer()
                            
                            if chapter.isListened {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if index == currentChapterIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showChapterList = false }
                }
            }
        }
    }
    
    // MARK: - Chapter Complete Overlay
    
    private var chapterCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: SpineTokens.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                
                Text("Chapter Complete!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                Text(currentChapter?.title ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                if hasNextChapter {
                    Button {
                        showChapterComplete = false
                        goToChapter(currentChapterIndex + 1)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Continue to Next Chapter")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(SpineTokens.Colors.accentGold)
                        .clipShape(Capsule())
                    }
                } else {
                    Text("🎉 You've finished the audiobook!")
                        .font(.headline)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                Button {
                    showChapterComplete = false
                } label: {
                    Text(hasNextChapter ? "Not Now" : "Close")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(SpineTokens.Spacing.xl)
        }
        .transition(.opacity)
    }
    
    // MARK: - XP Toast
    
    private func xpToast(reward: XPReward) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(SpineTokens.Colors.accentGold)
            Text("+\(reward.totalXP) XP")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    // MARK: - Player Setup
    
    private func setupPlayer() {
        // Find first unlistened chapter, or resume from the last played
        let resumeIndex = sortedChapters.firstIndex(where: { !$0.isListened }) ?? 0
        currentChapterIndex = resumeIndex
        
        player.onTrackFinished = {
            handleChapterFinished()
        }
        
        loadCurrentChapter()
    }
    
    private func loadCurrentChapter() {
        guard let chapter = currentChapter,
              let url = chapter.localFileURL else { return }
        
        do {
            player.startOffset = chapter.startOffset
            try player.load(url: url)
            
            // Resume from saved position
            if chapter.lastPlaybackPosition > chapter.startOffset {
                player.seek(to: chapter.lastPlaybackPosition)
            }
            
            player.play()
            sessionStartTime = Date()
        } catch {
            print("⚠️ Failed to load audio chapter: \(error)")
        }
    }
    
    private func goToChapter(_ index: Int) {
        savePlaybackPosition()
        currentChapterIndex = max(0, min(sortedChapters.count - 1, index))
        loadCurrentChapter()
    }
    
    private func savePlaybackPosition() {
        guard let chapter = currentChapter else { return }
        chapter.lastPlaybackPosition = player.currentTime
        try? modelContext.save()
    }
    
    private func handleChapterFinished() {
        guard let chapter = currentChapter else { return }
        
        // Mark as listened
        chapter.isListened = true
        chapter.lastPlaybackPosition = 0
        try? modelContext.save()
        
        // Award XP
        awardChapterXP(chapter: chapter)
        
        // Show chapter complete overlay
        withAnimation {
            showChapterComplete = true
        }
    }
    
    private func awardChapterXP(chapter: AudiobookChapter) {
        let xpEngine = XPEngine()
        
        // Find or create XP profile
        let descriptor = FetchDescriptor<XPProfile>()
        let profile: XPProfile
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
        } else {
            profile = XPProfile()
            modelContext.insert(profile)
        }
        
        let minutes = Date().timeIntervalSince(sessionStartTime) / 60.0
        let listenedCount = sortedChapters.filter { $0.isListened }.count
        
        // Create a lightweight reward — listening XP
        let baseXP = max(5, Int(minutes * 2))  // 2 XP per minute listened
        profile.totalXP += baseXP
        profile.dailyXP += baseXP
        
        let reward = XPReward(
            baseXP: baseXP,
            streakBonus: 0,
            speedBonus: 0,
            firstOfDayBonus: 0,
            bookFinishBonus: 0,
            wpm: 0,
            didLevelUp: false,
            previousLevel: profile.currentLevel,
            newLevel: profile.currentLevel,
            newAchievements: []
        )
        
        try? modelContext.save()
        latestReward = reward
        showXPToast = true
        
        // Reset session timer
        sessionStartTime = Date()
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    private var speedLabel: String {
        let rate = player.playbackRate
        if rate == 1.0 { return "1×" }
        if rate == floor(rate) { return "\(Int(rate))×" }
        return String(format: "%.1f×", rate)
    }
    
    private func cycleSpeed() {
        let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        let current = player.playbackRate
        let nextIndex = (speeds.firstIndex(of: current) ?? 1) + 1
        let newSpeed = speeds[nextIndex % speeds.count]
        player.setRate(newSpeed)
    }
    
    private func cycleSleepTimer() {
        let options: [Int?] = [15, 30, 45, 60, nil]
        let currentIndex = options.firstIndex(where: { $0 == sleepTimerMinutes }) ?? options.count - 1
        let nextIndex = (currentIndex + 1) % options.count
        sleepTimerMinutes = options[nextIndex]
        
        if let mins = sleepTimerMinutes {
            sleepTimerEnd = Date().addingTimeInterval(Double(mins) * 60)
            scheduleSleepTimer(minutes: mins)
        } else {
            sleepTimerEnd = nil
        }
    }
    
    private func scheduleSleepTimer(minutes: Int) {
        Task {
            try? await Task.sleep(for: .seconds(minutes * 60))
            if sleepTimerMinutes != nil {
                player.pause()
                sleepTimerMinutes = nil
                sleepTimerEnd = nil
            }
        }
    }
}
