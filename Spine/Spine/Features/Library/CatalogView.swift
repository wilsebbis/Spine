import SwiftUI
import SwiftData
import NaturalLanguage

// MARK: - Catalog View
// Discover tab: Apple Books-style browsing with genre carousels.
// Features:
//   • Books tab — browse 19K+ books by genre section/category
//   • Audiobooks tab — genre-filtered carousels for 1,700+ verified LibriVox titles
//   • Toast-style genre filter chips
//   • NLEmbedding semantic search ("plays from the 1600s", "romance with strong female leads")
//   • Book detail pages with genre chips, author link, download button

struct CatalogView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var libraryBooks: [Book]
    @State private var downloadService: DownloadService?
    @State private var audiobookDownloadService: AudiobookDownloadService?
    @State private var searchText = ""
    @State private var selectedTab: DiscoverTab = .books
    @State private var selectedGenreFilter: String?

    private let catalog = GutenbergCatalogManager.shared
    @State private var smartSearchResults: [GutenbergCatalogBook] = []
    @State private var isSearching = false

    enum DiscoverTab: String, CaseIterable {
        case books = "Books"
        case audiobooks = "Audiobooks"
    }

    private var libraryGutenbergIds: Set<String> {
        Set(libraryBooks.compactMap { $0.gutenbergId })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                    headerSection
                    tabPicker
                    
                    switch selectedTab {
                    case .books:
                        booksTabContent
                    case .audiobooks:
                        audiobooksTabContent
                    }
                }
                .padding(.vertical, SpineTokens.Spacing.md)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .searchable(text: $searchText, prompt: selectedTab == .books
                        ? "Search \(catalog.totalBooks.formatted()) books or ask anything…"
                        : "Search \(catalog.totalAudiobooks.formatted()) audiobooks or ask anything…")
            .onChange(of: searchText) { _, query in
                performSmartSearch(query: query)
            }
            .navigationBarHidden(true)
            .onAppear {
                if downloadService == nil {
                    downloadService = DownloadService(modelContext: modelContext)
                }
                if audiobookDownloadService == nil {
                    audiobookDownloadService = AudiobookDownloadService(modelContext: modelContext)
                }
            }
            .navigationDestination(for: CatalogDestination.self) { destination in
                switch destination {
                case .category(let categoryId, let audiobooksOnly):
                    CategoryDetailView(
                        categoryId: categoryId,
                        audiobooksOnly: audiobooksOnly,
                        catalog: catalog,
                        libraryGutenbergIds: libraryGutenbergIds,
                        downloadService: downloadService,
                        audiobookDownloadService: audiobookDownloadService
                    )
                case .bookDetail(let book):
                    CatalogBookDetailView(
                        book: book,
                        catalog: catalog,
                        libraryGutenbergIds: libraryGutenbergIds,
                        downloadService: downloadService,
                        audiobookDownloadService: audiobookDownloadService
                    )
                case .authorBooks(let author):
                    AuthorBooksView(
                        author: author,
                        catalog: catalog,
                        libraryGutenbergIds: libraryGutenbergIds,
                        downloadService: downloadService,
                        audiobookDownloadService: audiobookDownloadService
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text("Discover")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(SpineTokens.Colors.espresso)

            Text("\(catalog.totalBooks.formatted()) free books · \(catalog.totalAudiobooks.formatted()) audiobooks")
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DiscoverTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        selectedGenreFilter = nil
                    }
                } label: {
                    VStack(spacing: SpineTokens.Spacing.xs) {
                        HStack(spacing: SpineTokens.Spacing.xs) {
                            Image(systemName: tab == .books ? "book.fill" : "headphones")
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(SpineTokens.Typography.caption)
                        }
                        .foregroundStyle(selectedTab == tab ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)

                        Rectangle()
                            .fill(selectedTab == tab ? SpineTokens.Colors.accentGold : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }

    // MARK: - Genre Filter Chips

    private func genreChips(genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpineTokens.Spacing.xs) {
                // "All" chip
                Button {
                    withAnimation { selectedGenreFilter = nil }
                } label: {
                    Text("All")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedGenreFilter == nil
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.warmStone.opacity(0.12)
                        )
                        .foregroundStyle(selectedGenreFilter == nil ? .white : SpineTokens.Colors.espresso)
                        .clipShape(Capsule())
                }
                
                ForEach(genres, id: \.self) { genre in
                    Button {
                        withAnimation {
                            selectedGenreFilter = selectedGenreFilter == genre ? nil : genre
                        }
                    } label: {
                        Text(genre)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedGenreFilter == genre
                                    ? SpineTokens.Colors.accentGold
                                    : SpineTokens.Colors.warmStone.opacity(0.12)
                            )
                            .foregroundStyle(
                                selectedGenreFilter == genre ? .white : SpineTokens.Colors.espresso
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
        }
    }

    // MARK: - Books Tab

    private var booksTabContent: some View {
        LazyVStack(alignment: .leading, spacing: SpineTokens.Spacing.xl) {
            if !searchText.isEmpty {
                searchResultsView(audiobooksOnly: false)
            } else {
                ForEach(catalog.sections) { section in
                    sectionGroup(section, audiobooksOnly: false)
                }
            }
        }
    }

    // MARK: - Audiobooks Tab

    private var audiobooksTabContent: some View {
        LazyVStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
            if !searchText.isEmpty {
                searchResultsView(audiobooksOnly: true)
            } else {
                // Genre chips for quick filtering
                let topGenres = topAudiobookGenres()
                genreChips(genres: topGenres)
                
                if let genreFilter = selectedGenreFilter {
                    // Filtered view: show only books in this genre
                    genreFilteredAudiobooks(genre: genreFilter)
                } else {
                    // Full genre carousels
                    ForEach(catalog.audiobookSections) { section in
                        sectionGroup(section, audiobooksOnly: true)
                    }
                }
            }
        }
    }

    // MARK: - Section Group (genre carousels)

    private func sectionGroup(_ section: GutenbergCatalogSection, audiobooksOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
            Text(section.section)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(SpineTokens.Colors.espresso)
                .padding(.horizontal, SpineTokens.Spacing.md)

            ForEach(section.categories.prefix(4)) { category in
                if !category.books.isEmpty {
                    categoryCarousel(category, audiobooksOnly: audiobooksOnly)
                }
            }

            // Remaining categories as list
            if section.categories.count > 4 {
                VStack(spacing: 0) {
                    ForEach(section.categories.dropFirst(4)) { category in
                        if !category.books.isEmpty {
                            NavigationLink(value: CatalogDestination.category(category.bookshelf_id, audiobooksOnly: audiobooksOnly)) {
                                HStack(spacing: SpineTokens.Spacing.sm) {
                                    Text(category.name)
                                        .font(SpineTokens.Typography.body)
                                        .foregroundStyle(SpineTokens.Colors.espresso)
                                    Spacer()
                                    Text("\(category.books.count)")
                                        .font(SpineTokens.Typography.caption2)
                                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.5))
                                }
                                .padding(.horizontal, SpineTokens.Spacing.md)
                                .padding(.vertical, SpineTokens.Spacing.sm)
                            }
                            Divider().padding(.leading, SpineTokens.Spacing.md)
                        }
                    }
                }
                .background(SpineTokens.Colors.warmStone.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                .padding(.horizontal, SpineTokens.Spacing.md)
            }

            Divider().padding(.horizontal, SpineTokens.Spacing.md)
        }
    }

    // MARK: - Category Carousel

    private func categoryCarousel(_ category: GutenbergCatalogCategory, audiobooksOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            NavigationLink(value: CatalogDestination.category(category.bookshelf_id, audiobooksOnly: audiobooksOnly)) {
                HStack(spacing: SpineTokens.Spacing.xs) {
                    Text(category.name)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Spacer()
                    Text("\(category.books.count) titles")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: SpineTokens.Spacing.sm) {
                    ForEach(category.books.prefix(15)) { book in
                        NavigationLink(value: CatalogDestination.bookDetail(book)) {
                            CatalogBookCard(
                                book: book,
                                isInLibrary: libraryGutenbergIds.contains(book.gutenbergId),
                                hasAudiobook: catalog.librivoxIds.contains(book.ebook_id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
        }
    }

    // MARK: - Genre Filtered Audiobooks

    private func genreFilteredAudiobooks(genre: String) -> some View {
        let books = catalog.audiobookCatalog.filter { book in
            catalog.genres(for: book.ebook_id).contains(where: {
                $0.localizedCaseInsensitiveContains(genre)
            })
        }

        return VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
            HStack {
                Text(genre)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                Spacer()
                Text("\(books.count) audiobooks")
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            .padding(.horizontal, SpineTokens.Spacing.md)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 110), spacing: SpineTokens.Spacing.sm)
            ], spacing: SpineTokens.Spacing.md) {
                ForEach(books.prefix(60)) { book in
                    NavigationLink(value: CatalogDestination.bookDetail(book)) {
                        CatalogBookCard(
                            book: book,
                            isInLibrary: libraryGutenbergIds.contains(book.gutenbergId),
                            hasAudiobook: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
        }
    }

    // MARK: - Smart Search

    private func performSmartSearch(query: String) {
        guard !query.isEmpty else {
            smartSearchResults = []
            isSearching = false
            return
        }
        isSearching = true
        
        let pool = selectedTab == .audiobooks ? catalog.audiobookCatalog : catalog.allBooks
        let q = query.lowercased()
        
        // Phase 1: Keyword matching (title, author, genre)
        var scored: [(book: GutenbergCatalogBook, score: Int)] = []
        
        for book in pool {
            var score = 0
            let titleLower = book.title.lowercased()
            let authorLower = book.author.lowercased()
            let genres = catalog.genres(for: book.ebook_id).map { $0.lowercased() }
            let corpus = catalog.searchCorpus[book.ebook_id]?.lowercased() ?? ""
            
            // Exact title match
            if titleLower == q { score += 100 }
            else if titleLower.hasPrefix(q) { score += 80 }
            else if titleLower.contains(q) { score += 50 }
            
            // Author match
            if authorLower.contains(q) { score += 40 }
            
            // Genre match
            for genre in genres {
                if genre.contains(q) { score += 30 }
            }
            
            // Multi-word fuzzy: all query words appear somewhere in corpus
            let queryWords = q.split(separator: " ").map(String.init)
            if queryWords.count > 1 {
                let allMatch = queryWords.allSatisfy { corpus.contains($0) }
                if allMatch { score += 60 }
                else {
                    let matchCount = queryWords.filter { corpus.contains($0) }.count
                    if matchCount > 0 {
                        score += matchCount * 10
                    }
                }
            }
            
            if score > 0 {
                scored.append((book, score))
            }
        }
        
        // Phase 2: NLEmbedding semantic similarity (if available)
        if scored.count < 20 {
            if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
                // Find neighbors by semantic similarity
                let queryVec = embedding.vector(for: q)
                if queryVec != nil {
                    for book in pool where !scored.contains(where: { $0.book.ebook_id == book.ebook_id }) {
                        let corpus = catalog.searchCorpus[book.ebook_id] ?? book.title
                        let distance = embedding.distance(between: q, and: corpus)
                        // NLEmbedding.distance returns cosine distance; lower = more similar
                        if distance < 1.0 {
                            let nlScore = Int((1.0 - distance) * 40)
                            if nlScore > 5 {
                                scored.append((book, nlScore))
                            }
                        }
                    }
                }
            }
        }
        
        smartSearchResults = scored
            .sorted { $0.score > $1.score }
            .prefix(80)
            .map(\.book)
        
        isSearching = false
    }

    private func searchResultsView(audiobooksOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
            if isSearching {
                HStack {
                    ProgressView()
                    Text("Searching…")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
            
            if !smartSearchResults.isEmpty {
                Text("\(smartSearchResults.count) results")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .padding(.horizontal, SpineTokens.Spacing.md)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 110), spacing: SpineTokens.Spacing.sm)
                ], spacing: SpineTokens.Spacing.md) {
                    ForEach(smartSearchResults) { book in
                        NavigationLink(value: CatalogDestination.bookDetail(book)) {
                            CatalogBookCard(
                                book: book,
                                isInLibrary: libraryGutenbergIds.contains(book.gutenbergId),
                                hasAudiobook: catalog.librivoxIds.contains(book.ebook_id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            } else if !searchText.isEmpty && !isSearching {
                VStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.4))
                    Text("No results for \"\(searchText)\"")
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Text("Try \"mystery novels\", \"Shakespeare\", or \"19th century poetry\"")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, SpineTokens.Spacing.xl)
            }
        }
    }

    // MARK: - Helpers

    private func topAudiobookGenres() -> [String] {
        // Extract the most populated genre names from audiobook sections
        var genreCounts: [String: Int] = [:]
        for section in catalog.audiobookSections {
            for category in section.categories {
                genreCounts[category.name] = category.books.count
            }
        }
        return genreCounts
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map(\.key)
    }
}

// MARK: - Navigation Destination

enum CatalogDestination: Hashable {
    case category(Int, audiobooksOnly: Bool)
    case bookDetail(GutenbergCatalogBook)
    case authorBooks(String)
}

// MARK: - Book Detail View

struct CatalogBookDetailView: View {
    let book: GutenbergCatalogBook
    let catalog: GutenbergCatalogManager
    let libraryGutenbergIds: Set<String>
    let downloadService: DownloadService?
    let audiobookDownloadService: AudiobookDownloadService?
    
    @Environment(\.modelContext) private var modelContext
    @State private var isDownloading = false
    
    private var isInLibrary: Bool { libraryGutenbergIds.contains(book.gutenbergId) }
    private var hasAudiobook: Bool { catalog.librivoxIds.contains(book.ebook_id) }
    private var genres: [String] { catalog.genres(for: book.ebook_id) }
    private var librivoxMatch: LibriVoxMatch? { catalog.librivoxMatches[book.ebook_id] }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                // Hero: cover + info
                heroSection
                
                // Genre chips
                if !genres.isEmpty {
                    genreChipsSection
                }
                
                // Duration (if audiobook)
                if let match = librivoxMatch {
                    audiobookInfoSection(match)
                }
                
                // Actions
                actionButtons
                
                // About section
                aboutSection
            }
            .padding(.vertical, SpineTokens.Spacing.lg)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        HStack(alignment: .top, spacing: SpineTokens.Spacing.md) {
            // Cover
            AsyncImage(url: URL(string: book.cover_url)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    coverPlaceholder
                default:
                    coverPlaceholder
                        .overlay { ProgressView().tint(SpineTokens.Colors.accentGold) }
                }
            }
            .frame(width: 140, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            // Info
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                Text(book.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(4)
                
                // Author as clickable link
                NavigationLink(value: CatalogDestination.authorBooks(book.author)) {
                    HStack(spacing: 4) {
                        Text(book.author)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(SpineTokens.Colors.accentGold.opacity(0.6))
                    }
                }
                
                // Badges
                HStack(spacing: SpineTokens.Spacing.xs) {
                    if hasAudiobook {
                        Label("Audiobook", systemImage: "headphones")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SpineTokens.Colors.accentGold.opacity(0.15))
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                            .clipShape(Capsule())
                    }
                    
                    if isInLibrary {
                        Label("In Library", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    Label("Free", systemImage: "gift.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SpineTokens.Colors.warmStone.opacity(0.1))
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Genre Chips
    
    private var genreChipsSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text("Genres")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .padding(.horizontal, SpineTokens.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpineTokens.Spacing.xs) {
                    ForEach(genres, id: \.self) { genre in
                        NavigationLink(value: CatalogDestination.category(
                            categoryIdForGenre(genre),
                            audiobooksOnly: false
                        )) {
                            Text(genre)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(SpineTokens.Colors.warmStone.opacity(0.12))
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
        }
    }
    
    // MARK: - Audiobook Info
    
    private func audiobookInfoSection(_ match: LibriVoxMatch) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            HStack(spacing: SpineTokens.Spacing.sm) {
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audiobook Available")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    if !match.total_time.isEmpty {
                        Text("Duration: \(match.total_time)")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
                
                Spacer()
            }
            .padding(SpineTokens.Spacing.md)
            .background(SpineTokens.Colors.accentGold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Actions
    
    private var actionButtons: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            if !isInLibrary {
                // Download EPUB
                Button {
                    downloadEPUB()
                } label: {
                    Label(isDownloading ? "Downloading…" : "Download EPUB", systemImage: isDownloading ? "arrow.down.circle" : "arrow.down.to.line")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SpineTokens.Colors.accentGold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                }
                .disabled(isDownloading)
            } else {
                HStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Already in your library")
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            
            // Open on Gutenberg
            Link(destination: URL(string: "https://www.gutenberg.org/ebooks/\(book.ebook_id)")!) {
                Label("View on Project Gutenberg", systemImage: "safari")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SpineTokens.Colors.warmStone.opacity(0.1))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            
            // LibriVox link if audiobook
            if let match = librivoxMatch, let url = URL(string: match.librivox_url) {
                Link(destination: url) {
                    Label("Listen on LibriVox", systemImage: "headphones")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(SpineTokens.Colors.accentGold.opacity(0.1))
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                }
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("About")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                infoRow("Author", book.author)
                infoRow("Ebook ID", String(book.ebook_id))
                infoRow("Format", "EPUB3 with images")
                if hasAudiobook, let match = librivoxMatch {
                    infoRow("Audiobook", match.total_time.isEmpty ? "Available" : match.total_time)
                }
                if !genres.isEmpty {
                    infoRow("Categories", genres.joined(separator: ", "))
                }
            }
            .padding(SpineTokens.Spacing.md)
            .background(SpineTokens.Colors.warmStone.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso)
        }
    }
    
    // MARK: - Helpers
    
    private var coverPlaceholder: some View {
        ZStack {
            Rectangle().fill(
                LinearGradient(
                    colors: [SpineTokens.Colors.accentGold.opacity(0.15), SpineTokens.Colors.warmStone.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(SpineTokens.Colors.accentGold.opacity(0.5))
                Text(book.title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private func categoryIdForGenre(_ genre: String) -> Int {
        for section in catalog.sections {
            for category in section.categories {
                if category.name == genre {
                    return category.bookshelf_id
                }
            }
        }
        return 0
    }
    
    private func downloadEPUB() {
        isDownloading = true
        // Use the download service to fetch the book
        guard let service = downloadService else {
            isDownloading = false
            return
        }
        
        let newBook = Book(
            title: book.title,
            author: book.author,
            gutenbergId: book.gutenbergId
        )
        modelContext.insert(newBook)
        try? modelContext.save()
        
        Task {
            await service.download(book: newBook)
            isDownloading = false
        }
    }
}

// MARK: - Author Books View

struct AuthorBooksView: View {
    let author: String
    let catalog: GutenbergCatalogManager
    let libraryGutenbergIds: Set<String>
    let downloadService: DownloadService?
    let audiobookDownloadService: AudiobookDownloadService?
    
    private var authorBooks: [GutenbergCatalogBook] {
        catalog.allBooks.filter { $0.author.localizedCaseInsensitiveContains(author) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                    Text(author)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    let audioCount = authorBooks.filter { catalog.librivoxIds.contains($0.ebook_id) }.count
                    Text("\(authorBooks.count) works · \(audioCount) audiobooks")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                
                // Grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 110), spacing: SpineTokens.Spacing.sm)
                ], spacing: SpineTokens.Spacing.md) {
                    ForEach(authorBooks) { book in
                        NavigationLink(value: CatalogDestination.bookDetail(book)) {
                            CatalogBookCard(
                                book: book,
                                isInLibrary: libraryGutenbergIds.contains(book.gutenbergId),
                                hasAudiobook: catalog.librivoxIds.contains(book.ebook_id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
            .padding(.vertical, SpineTokens.Spacing.md)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationTitle(author)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Catalog Book Card

struct CatalogBookCard: View {
    let book: GutenbergCatalogBook
    let isInLibrary: Bool
    let hasAudiobook: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: book.cover_url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        cardCoverPlaceholder
                    default:
                        cardCoverPlaceholder
                            .overlay { ProgressView().tint(SpineTokens.Colors.accentGold) }
                    }
                }
                .frame(width: 110, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                VStack(spacing: 4) {
                    if hasAudiobook {
                        Image(systemName: "headphones")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(SpineTokens.Colors.accentGold))
                    }
                    if isInLibrary {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .background(Circle().fill(.white).padding(-1))
                    }
                }
                .padding(4)
            }

            Text(book.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SpineTokens.Colors.espresso)
                .lineLimit(2)
                .frame(width: 110, alignment: .leading)

            Text(book.author)
                .font(.system(size: 10))
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
        }
    }

    private var cardCoverPlaceholder: some View {
        ZStack {
            Rectangle().fill(
                LinearGradient(
                    colors: [SpineTokens.Colors.accentGold.opacity(0.15), SpineTokens.Colors.warmStone.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(SpineTokens.Colors.accentGold.opacity(0.5))
                Text(book.title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    let categoryId: Int
    let audiobooksOnly: Bool
    let catalog: GutenbergCatalogManager
    let libraryGutenbergIds: Set<String>
    let downloadService: DownloadService?
    let audiobookDownloadService: AudiobookDownloadService?
    
    @State private var searchText = ""

    private var category: GutenbergCatalogCategory? {
        let source = audiobooksOnly ? catalog.audiobookSections : catalog.sections
        for section in source {
            if let cat = section.categories.first(where: { $0.bookshelf_id == categoryId }) {
                return cat
            }
        }
        // Fallback: search all sections
        for section in catalog.sections {
            if let cat = section.categories.first(where: { $0.bookshelf_id == categoryId }) {
                if audiobooksOnly {
                    let audiobooks = cat.books.filter { catalog.librivoxIds.contains($0.ebook_id) }
                    return GutenbergCatalogCategory(name: cat.name, bookshelf_id: cat.bookshelf_id, books: audiobooks)
                }
                return cat
            }
        }
        return nil
    }

    private var filteredBooks: [GutenbergCatalogBook] {
        guard let cat = category else { return [] }
        if searchText.isEmpty { return cat.books }
        return cat.books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                if let cat = category {
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text(cat.name)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("\(cat.books.count) titles\(audiobooksOnly ? " with audiobooks" : "")")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 110), spacing: SpineTokens.Spacing.sm)
                    ], spacing: SpineTokens.Spacing.md) {
                        ForEach(filteredBooks) { book in
                            NavigationLink(value: CatalogDestination.bookDetail(book)) {
                                CatalogBookCard(
                                    book: book,
                                    isInLibrary: libraryGutenbergIds.contains(book.gutenbergId),
                                    hasAudiobook: catalog.librivoxIds.contains(book.ebook_id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                }
            }
            .padding(.vertical, SpineTokens.Spacing.md)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search \(category?.name ?? "")")
        .navigationTitle(category?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

