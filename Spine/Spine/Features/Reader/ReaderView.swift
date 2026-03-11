import SwiftUI
import SwiftData

// MARK: - Reader View
// The core reading experience. Renders normalized content with beautiful
// typography, theme support, and immersive reading UX.

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]
    @Query private var xpProfiles: [XPProfile]
    
    let book: Book
    let initialUnit: ReadingUnit
    
    @State private var currentUnit: ReadingUnit
    @State private var showingSettings = false
    @State private var showingReaction = false
    @State private var showControls = true
    @State private var sessionStartTime = Date()
    @State private var currentSession: DailySession?
    @State private var highlightText = ""
    @State private var showHighlightSheet = false
    @State private var showMicroReason = false
    @State private var showXPToast = false
    @State private var showCelebration = false
    @State private var latestReward: XPReward?
    
    private var currentSettings: UserSettings? { settings.first }
    
    private var theme: ReaderTheme {
        currentSettings?.readerTheme ?? .light
    }
    
    private var fontSize: CGFloat {
        CGFloat(currentSettings?.fontSize ?? 18)
    }
    
    private var lineHeight: CGFloat {
        CGFloat(currentSettings?.lineHeightMultiplier ?? 1.6)
    }
    
    private var useSerif: Bool {
        currentSettings?.useSerifFont ?? true
    }
    
    init(book: Book, initialUnit: ReadingUnit) {
        self.book = book
        self.initialUnit = initialUnit
        self._currentUnit = State(initialValue: initialUnit)
    }
    
    /// Convenience init — auto-selects first unread unit or first unit.
    init(book: Book) {
        self.book = book
        let units = book.sortedUnits
        let firstUnread = units.first(where: { !$0.isCompleted }) ?? units.first
        let unit = firstUnread ?? units.first!
        self.initialUnit = unit
        self._currentUnit = State(initialValue: unit)
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                    // Unit header
                    unitHeader
                    
                    // Reading content
                    readingContent
                    
                    // End-of-unit actions
                    unitFooter
                }
                .padding(.horizontal, SpineTokens.Spacing.lg)
                .padding(.top, SpineTokens.Spacing.xl)
                .padding(.bottom, 100)
            }
            
            // Top/Bottom controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .tabBar)
        .onAppear {
            startSession()
            AnalyticsService.shared.log(.readingUnitOpened, properties: [
                "bookTitle": book.title,
                "unitOrdinal": String(currentUnit.ordinal)
            ])
        }
        .onDisappear {
            endSession()
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsView()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingReaction) {
            ReactionSheet(book: book, unit: currentUnit) {
                navigateToNextUnit()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showHighlightSheet) {
            highlightSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showMicroReason) {
            MicroReasonSheet(book: book)
        }
        .overlay {
            if showXPToast, let reward = latestReward {
                XPToast(reward: reward, isPresented: $showXPToast)
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            if let reward = latestReward {
                CelebrationOverlay(reward: reward) {
                    showCelebration = false
                }
            }
        }
        .onTapGesture {
            withAnimation(SpineTokens.Animation.quick) {
                showControls.toggle()
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundColor: Color {
        switch theme {
        case .light: return SpineTokens.Colors.cream
        case .sepia: return SpineTokens.Colors.sepiaBackground
        case .dark: return SpineTokens.Colors.darkBackground
        }
    }
    
    private var textColor: Color {
        switch theme {
        case .light: return SpineTokens.Colors.espresso
        case .sepia: return SpineTokens.Colors.sepiaText
        case .dark: return SpineTokens.Colors.darkText
        }
    }
    
    private var secondaryTextColor: Color {
        switch theme {
        case .dark: return Color.white.opacity(0.5)
        default: return SpineTokens.Colors.subtleGray
        }
    }
    
    // MARK: - Unit Header
    
    private var unitHeader: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text(currentUnit.title)
                .font(useSerif ?
                    SpineTokens.Typography.readerSerif(size: fontSize + 6).bold() :
                    .system(size: fontSize + 6, weight: .bold)
                )
                .foregroundStyle(textColor)
            
            HStack(spacing: SpineTokens.Spacing.sm) {
                Label(
                    "\(Int(ceil(currentUnit.estimatedMinutes))) min read",
                    systemImage: "clock"
                )
                
                Text("·")
                
                Text("Unit \(currentUnit.ordinal + 1) of \(book.unitCount)")
            }
            .font(SpineTokens.Typography.caption)
            .foregroundStyle(secondaryTextColor)
            
            Divider()
                .padding(.top, SpineTokens.Spacing.xs)
        }
    }
    
    // MARK: - Reading Content
    
    private var readingContent: some View {
        let paragraphs = currentUnit.plainText.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return VStack(alignment: .leading, spacing: fontSize * lineHeight * 0.6) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(useSerif ?
                        SpineTokens.Typography.readerSerif(size: fontSize) :
                        SpineTokens.Typography.readerSans(size: fontSize)
                    )
                    .foregroundStyle(textColor)
                    .lineSpacing(fontSize * (lineHeight - 1))
                    .textSelection(.enabled)
                    .contextMenu {
                        Button {
                            highlightText = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                            showHighlightSheet = true
                        } label: {
                            Label("Highlight", systemImage: "highlighter")
                        }
                    }
            }
        }
    }
    
    // MARK: - Unit Footer
    
    private var unitFooter: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Divider()
            
            if !currentUnit.isCompleted {
                Button {
                    completeCurrentUnit()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Read")
                            .font(SpineTokens.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SpineTokens.Colors.successGreen)
                    Text("Completed")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.successGreen)
                }
                
                if hasNextUnit {
                    Button {
                        navigateToNextUnit()
                    } label: {
                        HStack {
                            Text("Next Unit")
                                .font(SpineTokens.Typography.headline)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(.top, SpineTokens.Spacing.lg)
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(textColor)
                        .padding(SpineTokens.Spacing.xs)
                }
                .glassEffect(.regular, in: Circle())
                
                Spacer()
                
                Text("\(currentUnit.ordinal + 1) / \(book.unitCount)")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(secondaryTextColor)
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(textColor)
                        .padding(SpineTokens.Spacing.xs)
                }
                .glassEffect(.regular, in: Circle())
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.top, SpineTokens.Spacing.xs)
            
            Spacer()
            
            // Bottom navigation
            HStack(spacing: SpineTokens.Spacing.xl) {
                Button {
                    navigateToPreviousUnit()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(hasPreviousUnit ? textColor : secondaryTextColor.opacity(0.3))
                        .padding(SpineTokens.Spacing.sm)
                }
                .glassEffect(.regular, in: Circle())
                .disabled(!hasPreviousUnit)
                
                Spacer()
                
                // Progress indicator
                let progress = Double(currentUnit.ordinal + 1) / Double(max(book.unitCount, 1))
                ProgressRing(
                    progress: progress,
                    lineWidth: 4,
                    size: 40
                )
                
                Spacer()
                
                Button {
                    navigateToNextUnit()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(hasNextUnit ? textColor : secondaryTextColor.opacity(0.3))
                        .padding(SpineTokens.Spacing.sm)
                }
                .glassEffect(.regular, in: Circle())
                .disabled(!hasNextUnit)
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.bottom, SpineTokens.Spacing.md)
        }
    }
    
    // MARK: - Highlight Sheet
    
    private var highlightSheet: some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.md) {
                Text(highlightText)
                    .font(SpineTokens.Typography.readerSerif(size: 16))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SpineTokens.Colors.softGold)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                
                TextField("Add a note…", text: .constant(""), axis: .vertical)
                    .font(SpineTokens.Typography.body)
                    .lineLimit(3...6)
                    .padding()
                    .background(SpineTokens.Colors.warmStone.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                
                Spacer()
            }
            .padding()
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveHighlight()
                        showHighlightSheet = false
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showHighlightSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Helpers
    
    private var hasNextUnit: Bool {
        let sorted = book.sortedUnits
        guard let idx = sorted.firstIndex(where: { $0.id == currentUnit.id }) else { return false }
        return idx + 1 < sorted.count
    }
    
    private var hasPreviousUnit: Bool {
        let sorted = book.sortedUnits
        guard let idx = sorted.firstIndex(where: { $0.id == currentUnit.id }) else { return false }
        return idx > 0
    }
    
    private func navigateToNextUnit() {
        let sorted = book.sortedUnits
        guard let idx = sorted.firstIndex(where: { $0.id == currentUnit.id }),
              idx + 1 < sorted.count else { return }
        withAnimation(SpineTokens.Animation.standard) {
            currentUnit = sorted[idx + 1]
        }
    }
    
    private func navigateToPreviousUnit() {
        let sorted = book.sortedUnits
        guard let idx = sorted.firstIndex(where: { $0.id == currentUnit.id }),
              idx > 0 else { return }
        withAnimation(SpineTokens.Animation.standard) {
            currentUnit = sorted[idx - 1]
        }
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        sessionStartTime = Date()
        let tracker = ProgressTracker(modelContext: modelContext)
        currentSession = tracker.startSession(for: book, unit: currentUnit)
    }
    
    private func endSession() {
        guard let session = currentSession else { return }
        let minutes = Date().timeIntervalSince(sessionStartTime) / 60.0
        session.minutesSpent = minutes
        if !session.isCompleted {
            // Session ended without completing unit
            try? modelContext.save()
        }
    }
    
    private func completeCurrentUnit() {
        guard let session = currentSession else { return }
        let minutes = Date().timeIntervalSince(sessionStartTime) / 60.0
        
        let tracker = ProgressTracker(modelContext: modelContext)
        tracker.completeUnit(currentUnit, book: book, session: session, minutesSpent: minutes)
        
        // Award XP
        let xpEngine = XPEngine()
        let profile = ensureXPProfile()
        
        let completedCount = book.readingUnits.filter { $0.isCompleted }.count
        let allBooks = (try? modelContext.fetch(FetchDescriptor<Book>())) ?? []
        let booksFinished = allBooks.filter { $0.readingProgress?.isFinished == true }.count
        let streak = book.readingProgress?.currentStreak ?? 0
        
        let reward = xpEngine.awardXP(
            profile: profile,
            unit: currentUnit,
            book: book,
            minutesSpent: minutes,
            currentStreak: streak,
            totalUnitsCompleted: completedCount,
            booksFinished: booksFinished,
            dailyXPGoal: currentSettings?.dailyXPGoal ?? 30
        )
        
        try? modelContext.save()
        latestReward = reward
        
        // Show appropriate UI
        if reward.didLevelUp || !reward.newAchievements.isEmpty {
            showCelebration = true
        } else {
            showXPToast = true
        }
        
        // Show micro-reason sheet every 5 completed units
        if completedCount > 0 && completedCount % 5 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showMicroReason = true
            }
        }
    }
    
    private func ensureXPProfile() -> XPProfile {
        if let existing = xpProfiles.first { return existing }
        let profile = XPProfile()
        modelContext.insert(profile)
        return profile
    }
    
    private func saveHighlight() {
        let highlight = Highlight(
            book: book,
            readingUnit: currentUnit,
            selectedText: highlightText,
            startLocator: 0,
            endLocator: highlightText.count
        )
        modelContext.insert(highlight)
        try? modelContext.save()
        
        AnalyticsService.shared.log(.highlightCreated, properties: [
            "bookTitle": book.title,
            "textLength": String(highlightText.count)
        ])
    }
}

// MARK: - Reader Settings View

struct ReaderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    private var currentSettings: UserSettings? { settings.first }
    
    var body: some View {
        NavigationStack {
            List {
                // Font size
                Section("Font Size") {
                    HStack {
                        Text("A")
                            .font(.system(size: 14))
                        
                        Slider(
                            value: Binding(
                                get: { currentSettings?.fontSize ?? 18 },
                                set: { currentSettings?.fontSize = $0 }
                            ),
                            in: 14...28,
                            step: 1
                        )
                        .tint(SpineTokens.Colors.accentGold)
                        
                        Text("A")
                            .font(.system(size: 24))
                    }
                }
                
                // Font style
                Section("Font Style") {
                    Picker("Font", selection: Binding(
                        get: { currentSettings?.useSerifFont ?? true },
                        set: { currentSettings?.useSerifFont = $0 }
                    )) {
                        Text("Serif").tag(true)
                        Text("Sans-serif").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Line spacing
                Section("Line Spacing") {
                    HStack {
                        Image(systemName: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                        
                        Slider(
                            value: Binding(
                                get: { currentSettings?.lineHeightMultiplier ?? 1.6 },
                                set: { currentSettings?.lineHeightMultiplier = $0 }
                            ),
                            in: 1.2...2.2,
                            step: 0.1
                        )
                        .tint(SpineTokens.Colors.accentGold)
                        
                        Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    }
                }
                
                // Theme
                Section("Theme") {
                    Picker("Theme", selection: Binding(
                        get: { currentSettings?.readerTheme ?? .light },
                        set: { currentSettings?.readerTheme = $0 }
                    )) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: currentSettings?.fontSize) { _, _ in
                try? modelContext.save()
                AnalyticsService.shared.log(.readerSettingsChanged)
            }
        }
    }
}
