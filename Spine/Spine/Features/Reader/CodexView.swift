import SwiftUI
import NaturalLanguage
import FoundationModels

// MARK: - Codex View (Merged Codex + Recap)
// Unified reference sheet combining:
//   • Story So Far — AI-generated narrative recap with key events, open threads
//   • Entities — NLTagger-extracted characters, locations, groups with AI descriptions
//   • Characters — AI-powered character status cards
// All spoiler-safe (only content through currentUnitOrdinal).

struct CodexView: View {
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    let currentUnitOrdinal: Int
    
    // MARK: - Tab
    
    enum CodexTab: String, CaseIterable {
        case story = "Story So Far"
        case entities = "Entities"
        case characters = "Characters"
    }
    
    @State private var selectedTab: CodexTab = .story
    
    // Entities state (NLTagger)
    @State private var entities: [CodexEntity] = []
    @State private var isLoadingEntities = true
    @State private var selectedEntity: CodexEntity?
    @State private var selectedFilter: EntityFilter = .all
    
    // Recap state (RAG service)
    @State private var storyResult: ReadingRecap?
    @State private var characterResult: CharacterRefresher?
    @State private var isLoadingRecap = false
    @State private var recapError: String?
    
    private let ragService = BookRAGServiceV2()
    private let tracker = CharacterTracker()
    
    enum EntityFilter: String, CaseIterable {
        case all = "All"
        case person = "Characters"
        case place = "Locations"
        case organization = "Groups"
    }
    
    private var filteredEntities: [CodexEntity] {
        switch selectedFilter {
        case .all: return entities
        case .person: return entities.filter { $0.type == .person }
        case .place: return entities.filter { $0.type == .place }
        case .organization: return entities.filter { $0.type == .organization }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Spoiler-safe badge
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "shield.checkered")
                        .font(.caption2)
                    Text("From Units 1–\(currentUnitOrdinal + 1) only")
                        .font(SpineTokens.Typography.caption2)
                }
                .foregroundStyle(SpineTokens.Colors.successGreen)
                .padding(.vertical, SpineTokens.Spacing.xs)
                
                // Tab picker
                Picker("Mode", selection: $selectedTab) {
                    ForEach(CodexTab.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xs)
                .onChange(of: selectedTab) { _, newTab in
                    if newTab == .story && storyResult == nil { loadStory() }
                    if newTab == .characters && characterResult == nil { loadCharacters() }
                }
                
                Divider()
                
                // Content
                switch selectedTab {
                case .story:
                    storyTab
                case .entities:
                    entitiesTab
                case .characters:
                    charactersTab
                }
            }
            .background(SpineTokens.Colors.cream)
            .navigationTitle("Codex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: SpineTokens.Spacing.xxs) {
                        Image(systemName: "apple.intelligence")
                            .font(.caption2)
                        Text("On-Device")
                            .font(SpineTokens.Typography.caption2)
                    }
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            .sheet(item: $selectedEntity) { entity in
                CodexEntityDetail(
                    entity: entity,
                    book: book,
                    currentUnitOrdinal: currentUnitOrdinal
                )
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            // Start loading entities and story concurrently
            async let entitiesTask: () = buildCodex()
            loadStory()
            await entitiesTask
        }
    }
    
    // MARK: - Story So Far Tab
    
    @ViewBuilder
    private var storyTab: some View {
        if isLoadingRecap && storyResult == nil {
            loadingView("Generating recap…")
        } else if let error = recapError, storyResult == nil {
            errorView(error) { loadStory() }
        } else if let recap = storyResult {
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                    // Coverage
                    if !recap.coverageNote.isEmpty {
                        Text(recap.coverageNote)
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .italic()
                    }
                    
                    // Recap paragraph
                    sectionHeader("Story So Far", icon: "book.fill")
                    Text(recap.recapParagraph)
                        .font(SpineTokens.Typography.readerSerif(size: 15))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .padding(SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.softGold)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    
                    // Key events
                    if !recap.majorEvents.isEmpty {
                        sectionHeader("Key Events", icon: "star.fill")
                        ForEach(Array(recap.majorEvents.enumerated()), id: \.offset) { i, event in
                            HStack(alignment: .top, spacing: SpineTokens.Spacing.sm) {
                                Text("\(i + 1)")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(SpineTokens.Colors.accentGold)
                                    .clipShape(Circle())
                                Text(event)
                                    .font(SpineTokens.Typography.body)
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                            }
                            .padding(SpineTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                    }
                    
                    // Open threads
                    if !recap.unresolvedThreads.isEmpty {
                        sectionHeader("Open Questions", icon: "questionmark.circle.fill")
                        ForEach(Array(recap.unresolvedThreads.enumerated()), id: \.offset) { _, thread in
                            HStack(alignment: .top, spacing: SpineTokens.Spacing.sm) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                    .foregroundStyle(SpineTokens.Colors.streakFlame)
                                    .padding(.top, 3)
                                Text(thread)
                                    .font(SpineTokens.Typography.body)
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                            }
                            .padding(SpineTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                    }
                    
                    // Don't forget
                    if !recap.importantDetailsToRemember.isEmpty {
                        sectionHeader("Don't Forget", icon: "lightbulb.fill")
                        ForEach(Array(recap.importantDetailsToRemember.enumerated()), id: \.offset) { _, detail in
                            HStack(alignment: .top, spacing: SpineTokens.Spacing.sm) {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                                    .padding(.top, 3)
                                Text(detail)
                                    .font(SpineTokens.Typography.body)
                                    .foregroundStyle(SpineTokens.Colors.espresso)
                            }
                            .padding(SpineTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                    }
                }
                .padding(SpineTokens.Spacing.md)
            }
        } else {
            emptyState("Generating story recap…")
        }
    }
    
    // MARK: - Entities Tab
    
    @ViewBuilder
    private var entitiesTab: some View {
        VStack(spacing: 0) {
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpineTokens.Spacing.xs) {
                    ForEach(EntityFilter.allCases, id: \.self) { filter in
                        filterPill(filter)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.vertical, SpineTokens.Spacing.xs)
            }
            
            Divider()
            
            if isLoadingEntities {
                loadingView("Building codex…")
            } else if filteredEntities.isEmpty {
                VStack(spacing: SpineTokens.Spacing.md) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 36))
                        .foregroundStyle(SpineTokens.Colors.warmStone)
                    Text("No \(selectedFilter.rawValue.lowercased()) found yet")
                        .font(SpineTokens.Typography.callout)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: SpineTokens.Spacing.xs) {
                        ForEach(filteredEntities) { entity in
                            entityRow(entity)
                        }
                    }
                    .padding(SpineTokens.Spacing.md)
                }
            }
        }
    }
    
    // MARK: - Characters Tab
    
    @ViewBuilder
    private var charactersTab: some View {
        if isLoadingRecap && characterResult == nil {
            loadingView("Analyzing characters…")
        } else if let error = recapError, characterResult == nil {
            errorView(error) { loadCharacters() }
        } else if let chars = characterResult {
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                    sectionHeader("Where They Stand", icon: "person.crop.circle")
                    ForEach(Array(chars.characters.enumerated()), id: \.offset) { _, c in
                        characterCard(name: c.name, status: c.status)
                    }
                }
                .padding(SpineTokens.Spacing.md)
            }
        } else {
            emptyState("Loading character status…")
        }
    }
    
    // MARK: - Reusable Components
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: SpineTokens.Spacing.xs) {
            Image(systemName: icon).foregroundStyle(SpineTokens.Colors.accentGold)
            Text(title)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
        }
        .padding(.top, SpineTokens.Spacing.xs)
    }
    
    private func characterCard(name: String, status: String) -> some View {
        HStack(alignment: .top, spacing: SpineTokens.Spacing.sm) {
            Circle().fill(avatarColor(for: name))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                Text(name)
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                Text(status)
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    private func filterPill(_ filter: EntityFilter) -> some View {
        Button {
            withAnimation(SpineTokens.Animation.quick) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: SpineTokens.Spacing.xxs) {
                if filter != .all {
                    Image(systemName: iconForType(filter))
                        .font(.caption2)
                }
                Text(filter.rawValue)
                    .font(SpineTokens.Typography.caption2)
            }
            .foregroundStyle(
                selectedFilter == filter ? .white : SpineTokens.Colors.espresso
            )
            .padding(.horizontal, SpineTokens.Spacing.sm)
            .padding(.vertical, SpineTokens.Spacing.xs)
            .background(
                selectedFilter == filter ?
                SpineTokens.Colors.espresso :
                SpineTokens.Colors.warmStone.opacity(0.3)
            )
            .clipShape(Capsule())
        }
    }
    
    private func entityRow(_ entity: CodexEntity) -> some View {
        Button {
            selectedEntity = entity
        } label: {
            HStack(spacing: SpineTokens.Spacing.sm) {
                Circle()
                    .fill(avatarColor(for: entity.name))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: entity.type.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                    Text(entity.name)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Text(entity.type.label)
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
                
                Text("\(entity.mentionCount)")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(entity.type.color)
                    .padding(.horizontal, SpineTokens.Spacing.xs)
                    .padding(.vertical, SpineTokens.Spacing.xxxs)
                    .background(entity.type.color.opacity(0.1))
                    .clipShape(Capsule())
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            .padding(SpineTokens.Spacing.sm)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
    }
    
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            ProgressView()
                .tint(SpineTokens.Colors.accentGold)
                .scaleEffect(1.2)
            Text(message)
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
            Text("Analyzing \(currentUnitOrdinal + 1) units")
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.warmStone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ msg: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(SpineTokens.Colors.streakFlame)
            Text(msg)
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
            Button("Retry") { retry() }
                .foregroundStyle(SpineTokens.Colors.accentGold)
        }
        .padding(SpineTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyState(_ msg: String) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            Text(msg)
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, SpineTokens.Spacing.xxl)
    }
    
    // MARK: - Data Loading
    
    private func buildCodex() async {
        let readUnits = book.sortedUnits.filter { $0.ordinal <= currentUnitOrdinal }
        var entityMap: [String: CodexEntity] = [:]
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        
        for unit in readUnits {
            tagger.string = unit.plainText
            let range = unit.plainText.startIndex..<unit.plainText.endIndex
            
            tagger.enumerateTags(
                in: range,
                unit: .word,
                scheme: .nameType,
                options: [.omitPunctuation, .omitWhitespace, .joinNames]
            ) { tag, tokenRange in
                guard let tag else { return true }
                
                let entityType: CodexEntityType?
                switch tag {
                case .personalName: entityType = .person
                case .placeName: entityType = .place
                case .organizationName: entityType = .organization
                default: entityType = nil
                }
                
                if let entityType {
                    let name = String(unit.plainText[tokenRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .capitalized
                    guard name.count >= 2 else { return true }
                    
                    let key = "\(entityType.rawValue)-\(name)"
                    if var existing = entityMap[key] {
                        existing.mentionCount += 1
                        if !existing.unitAppearances.contains(unit.ordinal) {
                            existing.unitAppearances.append(unit.ordinal)
                        }
                        entityMap[key] = existing
                    } else {
                        let context = extractSentence(
                            containing: tokenRange,
                            in: unit.plainText
                        )
                        entityMap[key] = CodexEntity(
                            name: name,
                            type: entityType,
                            mentionCount: 1,
                            firstAppearanceUnit: unit.ordinal,
                            firstContext: context,
                            unitAppearances: [unit.ordinal]
                        )
                    }
                }
                return true
            }
        }
        
        entities = entityMap.values
            .sorted { $0.mentionCount > $1.mentionCount }
        isLoadingEntities = false
        
        AnalyticsService.shared.log(.xrayOpened, properties: [
            "bookTitle": book.title,
            "entityCount": String(entities.count)
        ])
    }
    
    private func loadStory() {
        guard storyResult == nil else { return }
        isLoadingRecap = true
        recapError = nil
        Task {
            do {
                storyResult = try await ragService.storyRecap(
                    book: book,
                    currentUnitOrdinal: currentUnitOrdinal
                )
            } catch {
                recapError = error.localizedDescription
            }
            isLoadingRecap = false
        }
    }
    
    private func loadCharacters() {
        guard characterResult == nil else { return }
        isLoadingRecap = true
        recapError = nil
        Task {
            do {
                characterResult = try await ragService.characterRefresher(
                    book: book,
                    currentUnitOrdinal: currentUnitOrdinal
                )
            } catch {
                recapError = error.localizedDescription
            }
            isLoadingRecap = false
        }
    }
    
    // MARK: - Helpers
    
    private func iconForType(_ filter: EntityFilter) -> String {
        switch filter {
        case .all: return "circle"
        case .person: return "person.fill"
        case .place: return "mappin"
        case .organization: return "building.2"
        }
    }
    
    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            SpineTokens.Colors.espresso,
            SpineTokens.Colors.accentGold,
            SpineTokens.Colors.streakFlame,
            SpineTokens.Colors.successGreen,
            Color(hex: "6B5B95"),
            Color(hex: "88B04B"),
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    private func extractSentence(
        containing range: Range<String.Index>,
        in text: String
    ) -> String {
        let searchStart = text.index(range.lowerBound, offsetBy: -100, limitedBy: text.startIndex) ?? text.startIndex
        let searchEnd = text.index(range.upperBound, offsetBy: 100, limitedBy: text.endIndex) ?? text.endIndex
        let snippet = String(text[searchStart..<searchEnd])
        let sentences = snippet.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let entityText = String(text[range])
        if let match = sentences.first(where: { $0.contains(entityText) }) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Codex Entity Model

struct CodexEntity: Identifiable {
    var id: String { "\(type.rawValue)-\(name)" }
    let name: String
    let type: CodexEntityType
    var mentionCount: Int
    let firstAppearanceUnit: Int
    let firstContext: String
    var unitAppearances: [Int]
}

enum CodexEntityType: String {
    case person
    case place
    case organization
    
    var label: String {
        switch self {
        case .person: return "Character"
        case .place: return "Location"
        case .organization: return "Group"
        }
    }
    
    var icon: String {
        switch self {
        case .person: return "person.fill"
        case .place: return "mappin"
        case .organization: return "building.2"
        }
    }
    
    var color: Color {
        switch self {
        case .person: return SpineTokens.Colors.accentGold
        case .place: return SpineTokens.Colors.successGreen
        case .organization: return SpineTokens.Colors.streakFlame
        }
    }
}

// MARK: - Entity Detail with AI Description

struct CodexEntityDetail: View {
    let entity: CodexEntity
    let book: Book
    let currentUnitOrdinal: Int
    
    @State private var aiDescription: String?
    @State private var isGenerating = false
    @State private var generationError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(SpineTokens.Colors.warmStone)
                .frame(width: 36, height: 4)
                .padding(.top, SpineTokens.Spacing.sm)
            
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Header
                    VStack(spacing: SpineTokens.Spacing.sm) {
                        Circle()
                            .fill(entity.type.color)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Image(systemName: entity.type.icon)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        
                        Text(entity.name)
                            .font(SpineTokens.Typography.title)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        Text(entity.type.label)
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    .padding(.top, SpineTokens.Spacing.md)
                    
                    // Stats
                    HStack(spacing: SpineTokens.Spacing.xl) {
                        statBadge(
                            value: "\(entity.mentionCount)",
                            label: "mentions"
                        )
                        statBadge(
                            value: "Unit \(entity.firstAppearanceUnit + 1)",
                            label: "first seen"
                        )
                        statBadge(
                            value: "\(entity.unitAppearances.count)",
                            label: "units"
                        )
                    }
                    
                    Divider()
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    // Appearances
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("Appears In")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .textCase(.uppercase)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: SpineTokens.Spacing.xs) {
                                ForEach(entity.unitAppearances.sorted(), id: \.self) { unit in
                                    Text("Unit \(unit + 1)")
                                        .font(SpineTokens.Typography.caption2)
                                        .foregroundStyle(
                                            unit == currentUnitOrdinal ?
                                            Color.white :
                                            SpineTokens.Colors.espresso
                                        )
                                        .padding(.horizontal, SpineTokens.Spacing.xs)
                                        .padding(.vertical, SpineTokens.Spacing.xxxs)
                                        .background(
                                            unit == currentUnitOrdinal ?
                                            SpineTokens.Colors.accentGold :
                                            SpineTokens.Colors.warmStone.opacity(0.3)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    // First context
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("First Appearance")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .textCase(.uppercase)
                        
                        Text("\"\(entity.firstContext)\"")
                            .font(SpineTokens.Typography.readerSerif(size: 14))
                            .foregroundStyle(SpineTokens.Colors.espresso)
                            .italic()
                            .padding(SpineTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SpineTokens.Colors.softGold)
                            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    }
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    Divider()
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    // AI Description section
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                        HStack {
                            Image(systemName: "apple.intelligence")
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                            Text("AI Description")
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        
                        if let description = aiDescription {
                            Text(description)
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .padding(SpineTokens.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(SpineTokens.Colors.warmStone.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        } else if isGenerating {
                            HStack(spacing: SpineTokens.Spacing.sm) {
                                ProgressView()
                                    .tint(SpineTokens.Colors.accentGold)
                                Text("Generating…")
                                    .font(SpineTokens.Typography.caption)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                            }
                            .padding(SpineTokens.Spacing.sm)
                        } else if let error = generationError {
                            Text(error)
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.streakFlame)
                                .padding(SpineTokens.Spacing.sm)
                        } else {
                            Button {
                                generateDescription()
                            } label: {
                                HStack(spacing: SpineTokens.Spacing.xs) {
                                    Image(systemName: "sparkles")
                                    Text("Generate Description")
                                        .font(SpineTokens.Typography.headline)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, SpineTokens.Spacing.lg)
                                .padding(.vertical, SpineTokens.Spacing.sm)
                                .background(SpineTokens.Colors.accentGold)
                                .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                    
                    Spacer(minLength: SpineTokens.Spacing.xl)
                }
            }
        }
    }
    
    // MARK: - Stat Badge
    
    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: SpineTokens.Spacing.xxxs) {
            Text(value)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.accentGold)
            Text(label)
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
    }
    
    // MARK: - AI Description
    
    private func generateDescription() {
        guard FoundationModelService.isAvailable else {
            generationError = "Foundation Models not available on this device."
            return
        }
        
        isGenerating = true
        
        Task {
            do {
                let session = LanguageModelSession()
                let prompt = """
                You are an expert literary companion for "\(book.title)" by \(book.author).
                
                Describe "\(entity.name)" (\(entity.type.label.lowercased())) as they appear \
                in the book through Unit \(currentUnitOrdinal + 1). The reader has only read \
                this far — do NOT reveal spoilers from later in the book.
                
                First context where they appear: "\(entity.firstContext)"
                
                They appear \(entity.mentionCount) times across \(entity.unitAppearances.count) units.
                
                Write a 2-3 sentence description that captures who/what this \
                \(entity.type.label.lowercased()) is, their role or significance so far, \
                and any key details. Be concise and literary. No markdown formatting.
                """
                
                let response = try await session.respond(to: prompt)
                aiDescription = response.content
            } catch {
                generationError = "Could not generate: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}
