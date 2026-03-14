import SwiftUI
import SwiftData

// MARK: - Physical Book Tracker View
// Full tracking view for physical (paper) books.
// Features:
//   • Start Chapter → timer runs → Complete Chapter (records time)
//   • Skip button for front matter / already-read chapters (no XP or streak)
//   • Chapter grid shows time per chapter and skip/complete status
//   • XP/streak rewards on chapter completion via toast.

struct PhysicalBookTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book
    
    // MARK: - State
    
    @State private var showXPToast = false
    @State private var latestReward: XPReward?
    @State private var showConfetti = false
    @State private var isEditingNotes = false
    @State private var notesDraft = ""
    @State private var showSkipConfirm = false
    
    // Timer state
    @State private var isTimerRunning = false
    @State private var chapterStartTime: Date?
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    
    @Query private var profiles: [XPProfile]
    
    private var isFinished: Bool {
        book.physicalCurrentChapter >= book.totalPhysicalChapters
    }
    
    private var nextChapter: Int {
        book.physicalCurrentChapter + 1
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: SpineTokens.Spacing.lg) {
                headerSection
                progressSection
                chapterGrid
                
                if !isFinished {
                    // Start / Complete / Skip buttons
                    chapterActionButtons
                }
                
                ratingSection
                notesSection
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.vertical, SpineTokens.Spacing.lg)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopTimer() }
        .overlay {
            if showXPToast, let reward = latestReward {
                XPToast(
                    reward: reward,
                    currentStreak: book.readingProgress?.currentStreak ?? 0,
                    isPresented: $showXPToast,
                    onContinue: {}
                )
            }
        }
        .alert("Skip Chapter \(nextChapter)?", isPresented: $showSkipConfirm) {
            Button("Skip", role: .destructive) { skipChapter() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Skipped chapters don't earn XP or count toward your streak. Good for front matter or chapters you already read.")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: SpineTokens.Spacing.md) {
            if let coverData = book.coverImageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: SpineTokens.Radius.small)
                        .fill(SpineTokens.Colors.accentGold.opacity(0.15))
                        .frame(width: 80, height: 120)
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                Text(book.title)
                    .font(SpineTokens.Typography.body.bold())
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                HStack(spacing: SpineTokens.Spacing.xs) {
                    Image(systemName: "book.pages")
                    Text("Physical Book")
                }
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.accentGold)
                .padding(.horizontal, SpineTokens.Spacing.sm)
                .padding(.vertical, SpineTokens.Spacing.xxxs)
                .background(SpineTokens.Colors.accentGold.opacity(0.12))
                .clipShape(Capsule())
                
                if isFinished {
                    HStack(spacing: SpineTokens.Spacing.xxxs) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Completed")
                    }
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(.green)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        HStack(spacing: SpineTokens.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(SpineTokens.Colors.warmStone.opacity(0.15), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: book.physicalProgress)
                    .stroke(
                        SpineTokens.Colors.accentGold,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: book.physicalProgress)
                
                Text("\(Int(book.physicalProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(SpineTokens.Colors.espresso)
            }
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                Text("\(book.physicalCurrentChapter) of \(book.totalPhysicalChapters) chapters")
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                // Total reading time
                let totalMinutes = book.physicalChapterTimes.values.reduce(0, +)
                if totalMinutes > 0 {
                    HStack(spacing: SpineTokens.Spacing.xxxs) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(formatMinutes(totalMinutes)) total")
                            .font(SpineTokens.Typography.caption2)
                    }
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                if let streak = book.readingProgress?.currentStreak, streak > 0 {
                    HStack(spacing: SpineTokens.Spacing.xxxs) {
                        Text("🔥")
                        Text("\(streak) day streak")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
            }
            
            Spacer()
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.warmStone.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    // MARK: - Chapter Grid
    
    private var chapterGrid: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Chapters")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 56), spacing: SpineTokens.Spacing.xs)
            ], spacing: SpineTokens.Spacing.xs) {
                ForEach(1...book.totalPhysicalChapters, id: \.self) { chapter in
                    chapterCell(chapter)
                }
            }
        }
    }
    
    private func chapterCell(_ chapter: Int) -> some View {
        let isCompleted = chapter <= book.physicalCurrentChapter
        let isCurrent = chapter == nextChapter
        let isSkipped = book.physicalSkippedChapters.contains(chapter)
        let chapterMinutes = book.physicalChapterTimes[chapter]
        
        return VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: SpineTokens.Radius.small)
                    .fill(
                        isSkipped
                            ? SpineTokens.Colors.warmStone.opacity(0.15)
                            : isCompleted
                                ? SpineTokens.Colors.accentGold
                                : isCurrent
                                    ? SpineTokens.Colors.accentGold.opacity(0.2)
                                    : SpineTokens.Colors.warmStone.opacity(0.08)
                    )
                
                if isSkipped {
                    Image(systemName: "forward.fill")
                        .font(.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                } else if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(chapter)")
                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular, design: .rounded))
                        .foregroundStyle(
                            isCurrent
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.subtleGray
                        )
                }
            }
            .frame(width: 44, height: 44)
            .overlay {
                if isCurrent && !isFinished {
                    RoundedRectangle(cornerRadius: SpineTokens.Radius.small)
                        .stroke(SpineTokens.Colors.accentGold, lineWidth: 2)
                }
            }
            
            // Time label under completed chapters
            if let minutes = chapterMinutes, !isSkipped {
                Text(formatMinutes(minutes))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            } else if isSkipped {
                Text("skip")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.6))
            } else {
                Text(" ")
                    .font(.system(size: 9))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
    
    // MARK: - Chapter Action Buttons
    
    private var chapterActionButtons: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            if isTimerRunning {
                // Timer is running — show elapsed time + complete button
                timerDisplay
                
                Button {
                    completeChapter()
                } label: {
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Complete Chapter \(nextChapter)")
                                .font(SpineTokens.Typography.body.bold())
                            
                            Text("+20 XP  •  \(formatSeconds(elapsedSeconds))")
                                .font(SpineTokens.Typography.caption2)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "stop.circle")
                            .font(.title3)
                            .opacity(0.6)
                    }
                    .padding(SpineTokens.Spacing.md)
                    .foregroundStyle(.white)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    .shadow(color: SpineTokens.Colors.accentGold.opacity(0.3), radius: 8, y: 4)
                }
            } else {
                // Not started — show Start Chapter button
                Button {
                    startTimer()
                } label: {
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Chapter \(nextChapter)")
                                .font(SpineTokens.Typography.body.bold())
                            
                            Text("Tap when you begin reading")
                                .font(SpineTokens.Typography.caption2)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.6)
                    }
                    .padding(SpineTokens.Spacing.md)
                    .foregroundStyle(.white)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    .shadow(color: SpineTokens.Colors.accentGold.opacity(0.3), radius: 8, y: 4)
                }
            }
            
            // Skip button (always visible when not finished)
            Button {
                showSkipConfirm = true
            } label: {
                HStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "forward.fill")
                        .font(.subheadline)
                    
                    Text("Skip Chapter \(nextChapter)")
                        .font(SpineTokens.Typography.caption)
                    
                    Spacer()
                    
                    Text("No XP")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.7))
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.vertical, SpineTokens.Spacing.sm)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .background(SpineTokens.Colors.warmStone.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
        }
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        HStack(spacing: SpineTokens.Spacing.md) {
            // Animated pulse dot
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isTimerRunning ? 1.2 : 0.8)
                .opacity(isTimerRunning ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isTimerRunning)
            
            Text("Reading Chapter \(nextChapter)")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Spacer()
            
            Text(formatSeconds(elapsedSeconds))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(SpineTokens.Colors.espresso)
        }
        .padding(SpineTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                .fill(SpineTokens.Colors.accentGold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                        .stroke(SpineTokens.Colors.accentGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Your Rating")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            HStack(spacing: SpineTokens.Spacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            book.userRating = star == book.userRating ? nil : star
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: (book.userRating ?? 0) >= star ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(
                                (book.userRating ?? 0) >= star
                                    ? SpineTokens.Colors.accentGold
                                    : SpineTokens.Colors.warmStone.opacity(0.3)
                            )
                    }
                }
                
                Spacer()
                
                if let rating = book.userRating {
                    Text("\(rating)/5")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            .padding(SpineTokens.Spacing.sm)
            .background(SpineTokens.Colors.warmStone.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            HStack {
                Text("Reading Notes")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Spacer()
                
                Button {
                    if isEditingNotes {
                        book.userNotes = notesDraft.isEmpty ? nil : notesDraft
                        try? modelContext.save()
                    } else {
                        notesDraft = book.userNotes ?? ""
                    }
                    isEditingNotes.toggle()
                } label: {
                    Text(isEditingNotes ? "Save" : "Edit")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            
            if isEditingNotes {
                TextEditor(text: $notesDraft)
                    .font(SpineTokens.Typography.body)
                    .frame(minHeight: 120)
                    .padding(SpineTokens.Spacing.xs)
                    .background(SpineTokens.Colors.warmStone.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            } else if let notes = book.userNotes, !notes.isEmpty {
                Text(notes)
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .padding(SpineTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SpineTokens.Colors.warmStone.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            } else {
                Text("No notes yet. Tap Edit to start writing.")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .padding(SpineTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SpineTokens.Colors.warmStone.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            }
        }
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        chapterStartTime = Date()
        elapsedSeconds = 0
        isTimerRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = chapterStartTime {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }
    
    // MARK: - Complete Chapter
    
    private func completeChapter() {
        // Calculate reading time from timer
        let minutes: Double
        if let start = chapterStartTime {
            minutes = Date().timeIntervalSince(start) / 60.0
        } else {
            minutes = 5.0 // fallback
        }
        
        stopTimer()
        
        // Record chapter time
        let chapterNumber = nextChapter
        var times = book.physicalChapterTimes
        times[chapterNumber] = minutes
        book.physicalChapterTimes = times
        
        // Use ProgressTracker (handles streak, session, progress)
        let tracker = ProgressTracker(modelContext: modelContext)
        // Override the default 5 min with actual measured time
        tracker.completePhysicalChapter(book: book, minutesSpent: minutes)
        
        // Award XP
        if let profile = profiles.first {
            let xpEngine = XPEngine()
            let reward = xpEngine.awardPhysicalChapterXP(
                profile: profile,
                book: book,
                currentStreak: book.readingProgress?.currentStreak ?? 0
            )
            
            try? modelContext.save()
            
            latestReward = reward
            withAnimation { showXPToast = true }
        }
    }
    
    // MARK: - Skip Chapter
    
    private func skipChapter() {
        stopTimer()
        
        let chapterNumber = nextChapter
        
        // Mark as skipped
        var skipped = book.physicalSkippedChapters
        skipped.insert(chapterNumber)
        book.physicalSkippedChapters = skipped
        
        // Advance chapter counter without XP/streak/session
        book.physicalCurrentChapter += 1
        book.updatedAt = Date()
        
        // Update reading progress percentage
        if let progress = book.readingProgress {
            progress.completedPercent = book.physicalProgress
        }
        
        try? modelContext.save()
        
        AnalyticsService.shared.log(.readingUnitCompleted, properties: [
            "bookTitle": book.title,
            "chapter": String(chapterNumber),
            "action": "skipped"
        ])
    }
    
    // MARK: - Formatting
    
    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1 {
            return "<1m"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let h = Int(minutes) / 60
            let m = Int(minutes) % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
