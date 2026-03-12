import SwiftUI
import SwiftData

// MARK: - Reader View
// Infinite-scroll reading experience. All units render in a single
// continuous scroll. Unread units appear blurred until "Mark as Read"
// is tapped — like progressing down a game board.

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]
    @Query private var xpProfiles: [XPProfile]
    
    let book: Book
    let initialUnit: ReadingUnit
    
    // MARK: - Sheet Enum (single-sheet pattern)
    
    enum ReaderSheet: Identifiable {
        case settings
        case reaction
        case highlight
        case microReason
        case defineWord
        case explainParagraph
        case askTheBook
        case codex
        case discussion
        case shareHighlight
        case chapterList
        case chapterNotes
        case editHighlight
        case audioSync
        
        var id: String { String(describing: self) }
    }
    
    @State private var activeSheet: ReaderSheet?
    @State private var showControls = false
    @State private var sessionStartTime = Date()
    @State private var currentSession: DailySession?
    @State private var highlightText = ""
    @State private var selectedWord = ""
    @State private var selectedParagraph = ""
    @State private var showXPToast = false
    @State private var showCelebration = false
    @State private var latestReward: XPReward?
    @State private var activeUnitID: UUID?  // tracks which unit is being interacted with
    @State private var scrollTarget: UUID?
    @State private var tappedHighlightID: UUID?  // tracks which highlight was tapped for editing
    @State private var highlightNoteText = ""  // note text for new/edit highlights
    @State private var highlightColorHex = "C49B5C"  // selected color for highlight
    
    // Audio sync state
    @State private var audioSyncService = AudioSyncService()
    @State private var audioPlaybackEngine = AudioPlaybackEngine()
    @State private var audioTimings: ChapterTimings?
    @State private var isAudioMode = false

    
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
    
    private var marginSize: CGFloat {
        CGFloat(currentSettings?.marginSize ?? 24)
    }
    
    private var paragraphSpacingMultiplier: CGFloat {
        CGFloat(currentSettings?.paragraphSpacing ?? 0.6)
    }
    
    private var useDyslexiaFont: Bool {
        currentSettings?.useDyslexiaFont ?? false
    }
    
    
    /// Estimated minutes remaining in the book based on unread word counts.
    private var minutesRemaining: Int {
        let wpm = max(currentSettings?.wordsPerMinute ?? 225, 50)
        let unreadWords = readableUnits
            .filter { !$0.isCompleted }
            .reduce(0) { $0 + $1.plainText.split(separator: " ").count }
        return max(1, unreadWords / wpm)
    }
    
    /// Font for reading content — respects serif, dyslexia, and size settings.
    private var readerUIFont: UIFont {
        if useDyslexiaFont {
            // Rounded system font — clearer letter differentiation for dyslexia
            let descriptor = UIFont.systemFont(ofSize: fontSize, weight: .regular)
                .fontDescriptor.withDesign(.rounded)
            return UIFont(descriptor: descriptor ?? UIFontDescriptor(), size: fontSize)
        } else if useSerif {
            return UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
        } else {
            return .systemFont(ofSize: fontSize)
        }
    }
    
    private var sortedUnits: [ReadingUnit] {
        book.sortedUnits
    }
    
    /// Units filtered to exclude front matter, TOC, copyright, etc.
    private var readableUnits: [ReadingUnit] {
        sortedUnits.filter { !Self.isFrontMatter($0, bookTitle: book.title) }
    }
    
    /// The ordinal of the first unread unit (the "frontier").
    private var firstUnreadOrdinal: Int {
        readableUnits.first(where: { !$0.isCompleted })?.ordinal ?? Int.max
    }
    
    /// Windowed subset for rendering — only units near the frontier.
    /// Prevents creating hundreds of UITextViews for large books.
    private var visibleUnits: [ReadingUnit] {
        let all = readableUnits
        guard let frontierIdx = all.firstIndex(where: { $0.ordinal == firstUnreadOrdinal }) else {
            // All read — show last 10 units
            return Array(all.suffix(10))
        }
        let start = max(0, frontierIdx - 3)     // 3 completed units behind
        let end = min(all.count, frontierIdx + 8) // 8 ahead (locked, cheap)
        return Array(all[start..<end])
    }
    
    private var completedCount: Int {
        readableUnits.filter { $0.isCompleted }.count
    }
    
    // MARK: - Front Matter Detection
    
    /// Determines if a reading unit is front matter that should be hidden.
    private static func isFrontMatter(_ unit: ReadingUnit, bookTitle: String) -> Bool {
        let title = unit.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let text = unit.plainText.lowercased()
        
        // Skip by title
        let frontMatterTitles = [
            "copyright", "table of contents", "contents",
            "title page", "cover", "half title", "halftitle",
            "also by", "books by", "other books",
            "about the author", "about the publisher",
            "colophon", "imprint", "frontispiece",
            "acknowledgments", "acknowledgements",
        ]
        for fmTitle in frontMatterTitles {
            if title.contains(fmTitle) { return true }
        }
        
        // Skip very short units that are just metadata
        let strippedText = unit.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if strippedText.count < 50 { return true }
        
        // Skip units whose content is primarily a list of chapter names
        let lines = strippedText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.count > 5 {
            let chapterLines = lines.filter { $0.lowercased().hasPrefix("chapter ") }
            if Double(chapterLines.count) / Double(lines.count) > 0.4 {
                return true  // It's a TOC
            }
        }
        
        // Skip units that are copyright pages
        let copyrightIndicators = ["copyright", "all rights reserved", "isbn", "published by", "library of congress", "penguin random house", "first edition", "first printing"]
        let matchCount = copyrightIndicators.filter { text.contains($0) }.count
        if matchCount >= 2 { return true }
        
        return false
    }
    
    /// Filter paragraphs to remove redundant titles, chapter headings, and EPUB junk.
    private func filteredParagraphs(for unit: ReadingUnit) -> [String] {
        let raw = unit.plainText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let bookTitleLower = book.title.lowercased()
        let unitTitleLower = unit.title.lowercased()
        
        return raw.filter { paragraph in
            let lower = paragraph.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let stripped = lower.replacingOccurrences(of: " ", with: "")
            
            // Filter: exact book title
            if lower == bookTitleLower { return false }
            
            // Filter: chapter heading patterns ("CHAPTER 5", "Chapter V", etc.)
            if lower.hasPrefix("chapter ") && paragraph.count < 20 { return false }
            
            // Filter: unit title repeated
            if lower == unitTitleLower && paragraph.count < 40 { return false }
            
            // Filter: EPUB technical identifiers (ep_xxx, calibre IDs, etc.)
            if stripped.hasPrefix("ep_") || stripped.hasPrefix("calibre") { return false }
            if paragraph.count < 30 && paragraph.contains("_") && !paragraph.contains(" ") { return false }
            
            // Filter: very short lines that are just section markers
            if paragraph.count < 5 && paragraph.allSatisfy({ $0.isWhitespace || $0 == "*" || $0 == "-" || $0 == "—" }) { return false }
            
            return true
        }
    }
    
    init(book: Book, initialUnit: ReadingUnit) {
        self.book = book
        self.initialUnit = initialUnit
    }
    
    /// Convenience init — auto-selects first unread unit or first unit.
    init(book: Book) {
        self.book = book
        let units = book.sortedUnits
        let firstUnread = units.first(where: { !$0.isCompleted }) ?? units.first
        let unit = firstUnread ?? units.first!
        self.initialUnit = unit
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            // Infinite scroll content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleUnits, id: \.id) { unit in
                            unitBlock(unit)
                                .id(unit.id)
                        }
                        
                        // Bottom spacer
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, marginSize)
                    .padding(.top, SpineTokens.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollTarget) { _, newValue in
                    if let target = newValue {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        scrollTarget = nil
                    }
                }
                .onAppear {
                    // Scroll to initial unit
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        proxy.scrollTo(initialUnit.id, anchor: .top)
                    }
                }
            }
            
            // Full-screen tap to toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(SpineTokens.Animation.quick) {
                        showControls.toggle()
                    }
                }
                .allowsHitTesting(!showControls)
            
            // Controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .statusBarHidden(!showControls)
        .persistentSystemOverlays(showControls ? .automatic : .hidden)
        .onAppear {
            startSession()
            AnalyticsService.shared.log(.readingUnitOpened, properties: [
                "bookTitle": book.title,
                "unitOrdinal": String(initialUnit.ordinal)
            ])
            // Load cached audio timings if available
            if let cached = audioSyncService.loadCachedTimings(for: book.id) {
                audioTimings = cached
            }
        }
        .onDisappear {
            endSession()
            audioPlaybackEngine.pause()
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
        .overlay(alignment: .bottom) {
            // Audio controls bar when audio is active
            if isAudioMode, let timings = audioTimings {
                AudioControlsBar(engine: audioPlaybackEngine, timings: timings)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
    }
    
    // MARK: - Unit Block
    
    @ViewBuilder
    private func unitBlock(_ unit: ReadingUnit) -> some View {
        let isUnlocked = unit.isCompleted || unit.ordinal <= firstUnreadOrdinal
        let isCurrentFrontier = unit.ordinal == firstUnreadOrdinal
        
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
            // Unit header
            unitHeader(for: unit)
            
            // Reading content — dimmed if locked (lightweight, no blur)
            ZStack {
                unitContent(for: unit)
                    .opacity(isUnlocked ? 1 : 0.06)
                    .animation(.easeInOut(duration: 0.4), value: isUnlocked)
                
                // Lock overlay for dimmed units
                if !isUnlocked {
                    lockOverlay(unit: unit)
                }
            }
            
            // Mark as Read button (only for the frontier unit)
            if isCurrentFrontier && !unit.isCompleted {
                markAsReadButton(for: unit)
            } else if unit.isCompleted {
                completedBadge(for: unit)
            }
            
            // Divider between units
            unitDivider(ordinal: unit.ordinal)
        }
        .padding(.bottom, SpineTokens.Spacing.xl)
    }
    
    // MARK: - Unit Header
    
    private func unitHeader(for unit: ReadingUnit) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text(unit.title)
                .font(useSerif ?
                    SpineTokens.Typography.readerSerif(size: fontSize + 6).bold() :
                    .system(size: fontSize + 6, weight: .bold)
                )
                .foregroundStyle(textColor)
            
            HStack(spacing: SpineTokens.Spacing.sm) {
                Label(
                    "\(Int(ceil(unit.estimatedMinutes))) min read",
                    systemImage: "clock"
                )
                
                Text("·")
                
                Text("Unit \(unit.ordinal + 1) of \(book.unitCount)")
            }
            .font(SpineTokens.Typography.caption)
            .foregroundStyle(secondaryTextColor)
            
            Divider()
                .padding(.top, SpineTokens.Spacing.xs)
        }
    }
    
    // MARK: - Unit Content (paragraphs)
    
    private func unitContent(for unit: ReadingUnit) -> some View {
        let paragraphs = filteredParagraphs(for: unit)
        
        let readerFont = readerUIFont
        
        let readerTextColor: UIColor = UIColor(textColor)
        let spacing = fontSize * (lineHeight - 1)
        let isUnlocked = unit.isCompleted || unit.ordinal <= firstUnreadOrdinal
        
        return VStack(alignment: .leading, spacing: fontSize * lineHeight * paragraphSpacingMultiplier) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, trimmed in
                
                if isUnlocked {
                    // Build highlight ranges for this paragraph
                    let hlRanges: [SelectableTextView.HighlightRange] = unit.highlights
                        .filter { trimmed.contains($0.selectedText) }
                        .map { .init(id: $0.id, selectedText: $0.selectedText, colorHex: $0.colorHex) }
                    
                    // Interactive text for unlocked units
                    SelectableTextView(
                        text: trimmed,
                        font: readerFont,
                        textColor: readerTextColor,
                        lineSpacing: spacing,
                        highlights: hlRanges,
                        onHighlight: { selected in
                            activeUnitID = unit.id
                            highlightText = selected
                            activeSheet = .highlight
                        },
                        onShareQuote: FeatureFlags.shared.highlightSharing ? { selected in
                            activeUnitID = unit.id
                            highlightText = selected
                            activeSheet = .shareHighlight
                        } : nil,
                        onExplain: FeatureFlags.shared.explainParagraph ? { selected in
                            activeUnitID = unit.id
                            selectedParagraph = selected
                            activeSheet = .explainParagraph
                        } : nil,
                        onDefineWord: FeatureFlags.shared.defineWord ? { selected in
                            activeUnitID = unit.id
                            selectedWord = selected
                            selectedParagraph = trimmed
                            activeSheet = .defineWord
                        } : nil,
                        onTapHighlight: { highlightID in
                            tappedHighlightID = highlightID
                            activeSheet = .editHighlight
                        }
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Static text for locked units (no interaction)
                    Text(trimmed)
                        .font(useSerif ?
                            SpineTokens.Typography.readerSerif(size: fontSize) :
                            .system(size: fontSize)
                        )
                        .foregroundStyle(textColor)
                        .lineSpacing(spacing)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Lock Overlay
    
    private func lockOverlay(unit: ReadingUnit) -> some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundStyle(secondaryTextColor.opacity(0.6))
            
            Text("Complete Unit \(firstUnreadOrdinal + 1) to unlock")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(secondaryTextColor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
    
    // MARK: - Mark as Read Button
    
    private func markAsReadButton(for unit: ReadingUnit) -> some View {
        Button {
            completeUnit(unit)
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
        .padding(.top, SpineTokens.Spacing.md)
    }
    
    // MARK: - Completed Badge + Post-Completion Actions
    
    private func completedBadge(for unit: ReadingUnit) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Completed indicator
            HStack(spacing: SpineTokens.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SpineTokens.Colors.successGreen)
                Text("Completed")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.successGreen)
            }
            
            // Post-chapter action buttons
            HStack(spacing: SpineTokens.Spacing.sm) {
                // Rate this chapter
                postChapterButton(
                    icon: "star.fill",
                    label: "Rate"
                ) {
                    activeUnitID = unit.id
                    activeSheet = .reaction
                }
                
                // Discussion
                postChapterButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "Discuss"
                ) {
                    activeUnitID = unit.id
                    activeSheet = .discussion
                }
                
                // Private notes
                postChapterButton(
                    icon: "note.text",
                    label: "Notes"
                ) {
                    activeUnitID = unit.id
                    activeSheet = .chapterNotes
                }
            }
        }
        .padding(.top, SpineTokens.Spacing.sm)
    }
    
    private func postChapterButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: SpineTokens.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(SpineTokens.Typography.caption2)
            }
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpineTokens.Spacing.sm)
            .background(backgroundColor.opacity(0.8))
            .overlay {
                RoundedRectangle(cornerRadius: SpineTokens.Radius.small)
                    .strokeBorder(secondaryTextColor.opacity(0.2), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        }
    }
    
    // MARK: - Unit Divider
    
    private func unitDivider(ordinal: Int) -> some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            HStack {
                VStack { Divider() }
                
                // Progress node — like a game board checkpoint
                ZStack {
                    Circle()
                        .fill(ordinal < firstUnreadOrdinal
                            ? SpineTokens.Colors.successGreen
                            : (ordinal == firstUnreadOrdinal
                                ? SpineTokens.Colors.accentGold
                                : secondaryTextColor.opacity(0.3)))
                        .frame(width: 12, height: 12)
                    
                    if ordinal < firstUnreadOrdinal {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                VStack { Divider() }
            }
        }
        .padding(.top, SpineTokens.Spacing.lg)
    }
    
    // MARK: - Sheet Content
    
    @ViewBuilder
    private func sheetContent(_ sheet: ReaderSheet) -> some View {
        let interactedUnit = readableUnits.first(where: { $0.id == activeUnitID }) ?? initialUnit
        
        switch sheet {
        case .settings:
            ReaderSettingsView()
                .presentationDetents([.medium, .large])
        case .reaction:
            ReactionSheet(book: book, unit: interactedUnit) {}
                .presentationDetents([.medium])
        case .highlight:
            highlightSheet(unit: interactedUnit)
                .presentationDetents([.medium])
        case .microReason:
            MicroReasonSheet(book: book)
        case .defineWord:
            DefineWordSheet(word: selectedWord, context: selectedParagraph)
        case .explainParagraph:
            ExplainParagraphSheet(paragraphText: selectedParagraph, bookTitle: book.title)
        case .askTheBook:
            AskTheBookView(book: book, currentUnitOrdinal: interactedUnit.ordinal)
        case .codex:
            CodexView(book: book, currentUnitOrdinal: interactedUnit.ordinal)
        case .discussion:
            DiscussionView(book: book, unit: interactedUnit)
        case .shareHighlight:
            ShareHighlightSheet(
                highlightText: highlightText,
                bookTitle: book.title,
                bookAuthor: book.author
            )
        case .chapterList:
            chapterListSheet
                .presentationDetents([.medium, .large])
        case .chapterNotes:
            chapterNotesSheet(unit: interactedUnit)
                .presentationDetents([.medium, .large])
        case .editHighlight:
            editHighlightSheet
                .presentationDetents([.medium])
        case .audioSync:
            AudioImportSheet(
                book: book,
                syncService: audioSyncService
            ) { timings in
                audioTimings = timings
                isAudioMode = true
                if let url = audioSyncService.audioFileURL(for: book.id) {
                    try? audioPlaybackEngine.load(url: url)
                }
            }
        }
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
                
                // Progress
                let completed = completedCount
                Text("\(completed) / \(book.unitCount)")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(secondaryTextColor)
                
                Spacer()
                
                // Intelligence buttons
                HStack(spacing: SpineTokens.Spacing.xs) {
                    if FeatureFlags.shared.askTheBook {
                        controlButton(icon: "bubble.left.and.text.bubble.right") {
                            activeSheet = .askTheBook
                        }
                    }
                    
                    // Codex (merged entities + recap)
                    controlButton(icon: "text.book.closed") {
                        activeSheet = .codex
                    }
                    
                    // Audio sync (headphones icon)
                    controlButton(icon: audioTimings != nil ? "headphones" : "headphones.circle") {
                        if audioTimings != nil {
                            // Toggle audio mode
                            isAudioMode.toggle()
                            if isAudioMode {
                                if let url = audioSyncService.audioFileURL(for: book.id) {
                                    try? audioPlaybackEngine.load(url: url)
                                    audioPlaybackEngine.play()
                                }
                            } else {
                                audioPlaybackEngine.pause()
                            }
                        } else {
                            activeSheet = .audioSync
                        }
                    }
                    
                    controlButton(icon: "textformat.size") {
                        activeSheet = .settings
                    }
                    
                    controlButton(icon: "list.bullet") {
                        activeSheet = .chapterList
                    }
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.top, SpineTokens.Spacing.xs)
            
            Spacer()
            
            // Bottom progress bar + time left
            let progress = Double(completedCount) / Double(max(readableUnits.count, 1))
            VStack(spacing: SpineTokens.Spacing.xs) {
                HStack(spacing: SpineTokens.Spacing.md) {
                    ProgressView(value: progress)
                        .tint(SpineTokens.Colors.accentGold)
                    
                    Text("\(Int(progress * 100))%")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()
                }
                
                Text("~\(minutesRemaining) min left")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
            .padding(.bottom, SpineTokens.Spacing.md)
        }
    }
    
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(textColor)
                .padding(SpineTokens.Spacing.xs)
        }
        .glassEffect(.regular, in: Circle())
    }
    
    // MARK: - Background & Colors
    
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

    // MARK: - Highlight Sheet
    
    private func highlightSheet(unit: ReadingUnit) -> some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.md) {
                // Quoted text
                Text(highlightText)
                    .font(SpineTokens.Typography.readerSerif(size: 16))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor(hex: highlightColorHex) ?? .systemYellow).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                
                // Color picker
                highlightColorPicker
                
                // Note field
                TextField("Add a note\u{2026}", text: $highlightNoteText, axis: .vertical)
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
                        saveHighlight(unit: unit)
                        highlightNoteText = ""
                        highlightColorHex = "C49B5C"
                        activeSheet = nil
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        highlightNoteText = ""
                        highlightColorHex = "C49B5C"
                        activeSheet = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Edit Highlight Sheet
    
    private var editHighlightSheet: some View {
        let highlight = book.sortedUnits
            .flatMap { $0.highlights }
            .first(where: { $0.id == tappedHighlightID })
        
        return NavigationStack {
            if let hl = highlight {
                VStack(spacing: SpineTokens.Spacing.md) {
                    // Quoted text
                    Text(hl.selectedText)
                        .font(SpineTokens.Typography.readerSerif(size: 16))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor(hex: hl.colorHex) ?? .systemYellow).opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    
                    // Color picker
                    editHighlightColorPicker(highlight: hl)
                    
                    // Note field
                    TextEditor(text: Binding(
                        get: { hl.noteText ?? "" },
                        set: { hl.noteText = $0.isEmpty ? nil : $0; hl.updatedAt = Date() }
                    ))
                    .font(SpineTokens.Typography.body)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .frame(minHeight: 100)
                    .background(SpineTokens.Colors.warmStone.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    .overlay {
                        if (hl.noteText ?? "").isEmpty {
                            Text("Add a note\u{2026}")
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    // Delete button
                    Button(role: .destructive) {
                        modelContext.delete(hl)
                        try? modelContext.save()
                        activeSheet = nil
                    } label: {
                        Label("Delete Highlight", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, SpineTokens.Spacing.sm)
                    
                    Spacer()
                }
                .padding()
            } else {
                Text("Highlight not found")
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
        }
        .navigationTitle("Edit Highlight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    try? modelContext.save()
                    activeSheet = nil
                }
            }
        }
    }
    
    // MARK: - Highlight Color Picker
    
    private static let highlightColors: [(name: String, hex: String)] = [
        ("Gold", "C49B5C"),
        ("Yellow", "F5D547"),
        ("Green", "7BC47F"),
        ("Blue", "64B5F6"),
        ("Pink", "F48FB1"),
        ("Purple", "CE93D8"),
    ]
    
    private var highlightColorPicker: some View {
        HStack(spacing: SpineTokens.Spacing.md) {
            ForEach(Self.highlightColors, id: \.hex) { color in
                Circle()
                    .fill(Color(UIColor(hex: color.hex) ?? .systemYellow))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if highlightColorHex == color.hex {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .onTapGesture {
                        highlightColorHex = color.hex
                    }
            }
        }
    }
    
    private func editHighlightColorPicker(highlight: Highlight) -> some View {
        HStack(spacing: SpineTokens.Spacing.md) {
            ForEach(Self.highlightColors, id: \.hex) { color in
                Circle()
                    .fill(Color(UIColor(hex: color.hex) ?? .systemYellow))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if highlight.colorHex == color.hex {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .onTapGesture {
                        highlight.colorHex = color.hex
                        highlight.updatedAt = Date()
                    }
            }
        }
    }
    
    // MARK: - Chapter List Sheet
    
    private var chapterListSheet: some View {
        NavigationStack {
            List {
                ForEach(readableUnits, id: \.id) { unit in
                    Button {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollTarget = unit.id
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.title)
                                    .font(SpineTokens.Typography.body)
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                                
                                Text("\(Int(ceil(unit.estimatedMinutes))) min")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                            }
                            
                            Spacer()
                            
                            if unit.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(SpineTokens.Colors.successGreen)
                            } else if unit.ordinal == firstUnreadOrdinal {
                                Image(systemName: "book.fill")
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
                    Button("Done") { activeSheet = nil }
                }
            }
        }
    }
    
    // MARK: - Chapter Notes Sheet
    
    private func chapterNotesSheet(unit: ReadingUnit) -> some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.md) {
                Text(unit.title)
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                TextEditor(text: Binding(
                    get: { unit.privateNotes ?? "" },
                    set: { unit.privateNotes = $0 }
                ))
                .font(SpineTokens.Typography.body)
                .scrollContentBackground(.hidden)
                .padding(SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.warmStone.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                .frame(minHeight: 150)
                
                Text("Your private thoughts on this chapter. These won't be shared — use them for your own review later.")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Chapter Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        activeSheet = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        sessionStartTime = Date()
        let tracker = ProgressTracker(modelContext: modelContext)
        currentSession = tracker.startSession(for: book, unit: initialUnit)
    }
    
    private func endSession() {
        guard let session = currentSession else { return }
        let minutes = Date().timeIntervalSince(sessionStartTime) / 60.0
        session.minutesSpent = minutes
        if !session.isCompleted {
            try? modelContext.save()
        }
    }
    
    private func completeUnit(_ unit: ReadingUnit) {
        guard let session = currentSession else { return }
        let minutes = Date().timeIntervalSince(sessionStartTime) / 60.0
        
        let tracker = ProgressTracker(modelContext: modelContext)
        tracker.completeUnit(unit, book: book, session: session, minutesSpent: minutes)
        
        // Award XP
        let xpEngine = XPEngine()
        let profile = ensureXPProfile()
        
        let completedCount = book.readingUnits.filter { $0.isCompleted }.count
        let allBooks = (try? modelContext.fetch(FetchDescriptor<Book>())) ?? []
        let booksFinished = allBooks.filter { $0.readingProgress?.isFinished == true }.count
        let streak = book.readingProgress?.currentStreak ?? 0
        
        let reward = xpEngine.awardXP(
            profile: profile,
            unit: unit,
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
        
        // Start new session for next unit
        sessionStartTime = Date()
        
        // Analytics
        AnalyticsService.shared.log(.readingUnitCompleted, properties: [
            "bookTitle": book.title,
            "unitOrdinal": String(unit.ordinal),
            "minutesSpent": String(format: "%.1f", minutes)
        ])
        

    }
    
    private func ensureXPProfile() -> XPProfile {
        if let existing = xpProfiles.first { return existing }
        let profile = XPProfile()
        modelContext.insert(profile)
        return profile
    }
    
    private func saveHighlight(unit: ReadingUnit) {
        let highlight = Highlight(
            book: book,
            readingUnit: unit,
            selectedText: highlightText,
            startLocator: 0,
            endLocator: highlightText.count,
            noteText: highlightNoteText.isEmpty ? nil : highlightNoteText,
            colorHex: highlightColorHex
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
                Section("Font") {
                    Picker("Font", selection: Binding(
                        get: { currentSettings?.useSerifFont ?? true },
                        set: { currentSettings?.useSerifFont = $0 }
                    )) {
                        Text("Serif").tag(true)
                        Text("Sans-serif").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Dyslexia-Friendly Font", isOn: Binding(
                        get: { currentSettings?.useDyslexiaFont ?? false },
                        set: { currentSettings?.useDyslexiaFont = $0 }
                    ))
                    .tint(SpineTokens.Colors.accentGold)
                }
                
                // Spacing
                Section("Spacing") {
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("Line Spacing")
                            .font(SpineTokens.Typography.caption)
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
                    
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("Paragraph Spacing")
                            .font(SpineTokens.Typography.caption)
                        HStack {
                            Text("Tight")
                                .font(.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                            
                            Slider(
                                value: Binding(
                                    get: { currentSettings?.paragraphSpacing ?? 0.6 },
                                    set: { currentSettings?.paragraphSpacing = $0 }
                                ),
                                in: 0.3...1.0,
                                step: 0.1
                            )
                            .tint(SpineTokens.Colors.accentGold)
                            
                            Text("Wide")
                                .font(.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("Margins")
                            .font(SpineTokens.Typography.caption)
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                            
                            Slider(
                                value: Binding(
                                    get: { currentSettings?.marginSize ?? 24 },
                                    set: { currentSettings?.marginSize = $0 }
                                ),
                                in: 12...48,
                                step: 4
                            )
                            .tint(SpineTokens.Colors.accentGold)
                        }
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
                

                
                // Reading Speed
                Section {
                    HStack {
                        Text("\(currentSettings?.wordsPerMinute ?? 225) WPM")
                            .font(SpineTokens.Typography.callout)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Stepper("", value: Binding(
                            get: { currentSettings?.wordsPerMinute ?? 225 },
                            set: { currentSettings?.wordsPerMinute = $0 }
                        ), in: 100...600, step: 25)
                        .labelsHidden()
                    }
                } header: {
                    Label("Reading Speed", systemImage: "speedometer")
                } footer: {
                    Text("Used for time-left estimates. Average adult: 200–250 WPM.")
                }
                
                // Reset to Defaults
                Section {
                    Button(role: .destructive) {
                        resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                                .font(SpineTokens.Typography.callout)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: currentSettings?.fontSize) { _, _ in
                saveSettings()
            }
            .onChange(of: currentSettings?.lineHeightMultiplier) { _, _ in
                saveSettings()
            }
            .onChange(of: currentSettings?.marginSize) { _, _ in
                saveSettings()
            }
            .onChange(of: currentSettings?.paragraphSpacing) { _, _ in
                saveSettings()
            }

        }
    }
    
    private func saveSettings() {
        try? modelContext.save()
        AnalyticsService.shared.log(.readerSettingsChanged)
    }
    
    private func resetToDefaults() {
        guard let s = currentSettings else { return }
        s.fontSize = 18.0
        s.lineHeightMultiplier = 1.6
        s.useSerifFont = true
        s.marginSize = 24.0
        s.paragraphSpacing = 0.6
        s.useDyslexiaFont = false
        s.wordsPerMinute = 225
        s.readerTheme = .light
        saveSettings()
    }
}
