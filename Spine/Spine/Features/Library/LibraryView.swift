import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Library View
// Momentum-first library: Continue · Up Next · Completed · All.
// Replaces library management with reading momentum management.

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Book> { $0.isDownloaded == true || $0.hasAudiobook == true }, sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Query private var settings: [UserSettings]
    
    @State private var showingFilePicker = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var searchText = ""
    @State private var selectedBook: Book?
    @State private var selectedAudiobook: Book?
    @State private var selectedSegment: LibrarySegment = .all
    @State private var sortOrder: LibrarySortOrder = .recent
    @State private var useGridLayout = true
    @State private var showAddPhysicalBook = false
    @State private var selectedPhysicalBook: Book?
    
    // MARK: - Segments
    
    enum LibrarySegment: String, CaseIterable {
        case continueReading = "Continue"
        case upNext = "Up Next"
        case completed = "Completed"
        case all = "All"
        case uploaded = "Uploaded"
        case physicalBooks = "Physical"
        case audiobooks = "Audiobooks"
    }
    
    enum LibrarySortOrder: String, CaseIterable {
        case recent = "Recent"
        case title = "Title"
        case author = "Author"
    }
    
    private var segmentedBooks: [Book] {
        let base: [Book]
        switch selectedSegment {
        case .continueReading:
            base = books.filter { ($0.isDownloaded || $0.isPhysicalBook) && $0.importStatus == .completed && $0.readingProgress?.isFinished != true && ($0.readingProgress?.completedUnitCount ?? 0) > 0 }
        case .upNext:
            base = books.filter { $0.isDownloaded && $0.isUpNext && $0.readingProgress?.isFinished != true }
        case .completed:
            base = books.filter { ($0.isDownloaded || $0.isPhysicalBook) && $0.readingProgress?.isFinished == true }
        case .all:
            base = books.filter { $0.isDownloaded || $0.isPhysicalBook }
        case .uploaded:
            base = books.filter { $0.sourceType == .local && $0.isDownloaded }
        case .physicalBooks:
            base = books.filter { $0.isPhysicalBook }
        case .audiobooks:
            base = books.filter { $0.hasAudiobook }
        }
        
        // Apply search
        let searched = searchText.isEmpty ? base : base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
        
        // Apply sort
        switch sortOrder {
        case .recent:
            return searched.sorted { $0.updatedAt > $1.updatedAt }
        case .title:
            return searched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return searched.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        }
    }
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 150), spacing: SpineTokens.Spacing.md)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Segment picker
                    segmentPicker
                    
                    if books.isEmpty {
                        emptyLibrary
                    } else if selectedSegment == .audiobooks {
                        audiobookGridSection
                    } else if selectedSegment == .physicalBooks {
                        physicalBooksSection
                    } else if segmentedBooks.isEmpty {
                        emptySegment
                    } else {
                        if selectedSegment == .all {
                            ForYouView()
                        }
                        
                        if useGridLayout {
                            gridView
                        } else {
                            listView
                        }
                    }
                }
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        // Grid/List toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                useGridLayout.toggle()
                            }
                        } label: {
                            Image(systemName: useGridLayout ? "list.bullet" : "square.grid.2x2")
                        }
                        
                        // Sort menu
                        Menu {
                            ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        // Import / Add
                        Menu {
                            Button {
                                showingFilePicker = true
                            } label: {
                                Label("Import EPUB", systemImage: "doc.badge.plus")
                            }
                            
                            Button {
                                showAddPhysicalBook = true
                            } label: {
                                Label("Add Physical Book", systemImage: "book.pages")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .overlay {
                if isImporting {
                    importingOverlay
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error")
            }
            .navigationDestination(item: $selectedBook) { book in
                if book.isPhysicalBook {
                    PhysicalBookTrackerView(book: book)
                } else {
                    BookDetailView(book: book)
                }
            }
            .navigationDestination(item: $selectedPhysicalBook) { book in
                PhysicalBookTrackerView(book: book)
            }
            .sheet(isPresented: $showAddPhysicalBook) {
                AddPhysicalBookView()
            }
            .fullScreenCover(item: $selectedAudiobook) { book in
                AudiobookPlayerView(book: book)
            }
        }
    }
    
    // MARK: - Physical Books Grid
    
    private var physicalBooksSection: some View {
        let physicalBooks = books.filter { $0.isPhysicalBook }
        return Group {
            if physicalBooks.isEmpty {
                VStack(spacing: SpineTokens.Spacing.md) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 48))
                        .foregroundStyle(SpineTokens.Colors.warmStone.opacity(0.3))
                    
                    Text("No physical books yet")
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    
                    Button {
                        showAddPhysicalBook = true
                    } label: {
                        Label("Add a Book", systemImage: "plus")
                            .font(SpineTokens.Typography.body.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, SpineTokens.Spacing.lg)
                            .padding(.vertical, SpineTokens.Spacing.sm)
                            .background(SpineTokens.Colors.accentGold)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, SpineTokens.Spacing.xxl)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: SpineTokens.Spacing.md)
                ], spacing: SpineTokens.Spacing.md) {
                    ForEach(physicalBooks) { book in
                        physicalBookCard(book)
                            .onTapGesture {
                                selectedBook = book
                            }
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
        }
    }
    
    private func physicalBookCard(_ book: Book) -> some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Cover
            ZStack(alignment: .bottomTrailing) {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        SpineTokens.Colors.accentGold.opacity(0.25),
                                        SpineTokens.Colors.warmStone.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 200)
                        
                        VStack(spacing: SpineTokens.Spacing.xs) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                            
                            Text(book.title)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, SpineTokens.Spacing.sm)
                        }
                    }
                }
                
                // Progress badge
                Text("\(book.physicalCurrentChapter)/\(book.totalPhysicalChapters)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(Capsule())
                    .padding(6)
            }
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            // Title + Author
            VStack(spacing: 2) {
                Text(book.title)
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Audiobook Grid
    
    private var audiobookGridSection: some View {
        let audiobooks = books.filter { $0.hasAudiobook }
        return Group {
            if audiobooks.isEmpty {
                emptySegment
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: SpineTokens.Spacing.md)
                ], spacing: SpineTokens.Spacing.md) {
                    ForEach(audiobooks) { book in
                        audiobookCard(book)
                            .onTapGesture {
                                selectedAudiobook = book
                            }
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
            }
        }
    }
    
    private func audiobookCard(_ book: Book) -> some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Square cover
            ZStack(alignment: .bottomTrailing) {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                SpineTokens.Colors.espresso.opacity(0.8),
                                SpineTokens.Colors.espresso
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 28))
                                .foregroundStyle(SpineTokens.Colors.accentGold.opacity(0.6))
                            
                            Text(book.title)
                                .font(.system(size: 9, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 8)
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                }
                
                // Headphones badge
                Image(systemName: "headphones")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(SpineTokens.Colors.espresso.opacity(0.75))
                    .clipShape(Circle())
                    .padding(6)
                
                // Play overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            
            // Info
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                Text(book.title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(book.author)
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .lineLimit(1)
                    
                    if (book.audiobookDurationSeconds ?? 0) > 0 {
                        Text("·")
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                        let dur = book.audiobookDurationSeconds ?? 0
                        let h = dur / 3600
                        let m = (dur % 3600) / 60
                        Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Listening progress
            if !book.sortedAudioChapters.isEmpty {
                let listened = book.sortedAudioChapters.filter { $0.isListened }.count
                let total = book.sortedAudioChapters.count
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SpineTokens.Colors.warmStone.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SpineTokens.Colors.accentGold)
                            .frame(width: geo.size.width * (Double(listened) / Double(max(1, total))))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Segment Picker
    
    private var segmentPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpineTokens.Spacing.xs) {
                ForEach(LibrarySegment.allCases, id: \.self) { segment in
                    let count = countForSegment(segment)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSegment = segment
                        }
                    } label: {
                        HStack(spacing: SpineTokens.Spacing.xxs) {
                            Text(segment.rawValue)
                                .font(SpineTokens.Typography.caption2)
                            if count > 0 && segment != .all {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        selectedSegment == segment
                                        ? Color.white.opacity(0.3)
                                        : SpineTokens.Colors.warmStone.opacity(0.3)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(selectedSegment == segment ? .white : SpineTokens.Colors.espresso)
                        .padding(.horizontal, SpineTokens.Spacing.md)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                        .background(
                            selectedSegment == segment
                            ? SpineTokens.Colors.espresso
                            : SpineTokens.Colors.warmStone.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.vertical, SpineTokens.Spacing.sm)
        }
    }
    
    private func countForSegment(_ segment: LibrarySegment) -> Int {
        switch segment {
        case .continueReading:
            return books.filter { $0.isDownloaded && $0.importStatus == .completed && $0.readingProgress?.isFinished != true && ($0.readingProgress?.completedUnitCount ?? 0) > 0 }.count
        case .upNext:
            return books.filter { $0.isDownloaded && $0.isUpNext && $0.readingProgress?.isFinished != true }.count
        case .completed:
            return books.filter { $0.isDownloaded && $0.readingProgress?.isFinished == true }.count
        case .all:
            return books.filter { $0.isDownloaded || $0.isPhysicalBook }.count
        case .uploaded:
            return books.filter { $0.sourceType == .local && $0.isDownloaded }.count
        case .audiobooks:
            return books.filter { $0.hasAudiobook }.count
        case .physicalBooks:
            return books.filter { $0.isPhysicalBook }.count
        }
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: SpineTokens.Spacing.md) {
            ForEach(segmentedBooks) { book in
                bookCard(book)
                    .onTapGesture {
                        selectedBook = book
                    }
                    .contextMenu {
                        bookContextMenu(book)
                    }
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        LazyVStack(spacing: SpineTokens.Spacing.xs) {
            ForEach(segmentedBooks) { book in
                listRow(book)
                    .onTapGesture {
                        selectedBook = book
                    }
                    .contextMenu {
                        bookContextMenu(book)
                    }
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    private func listRow(_ book: Book) -> some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            // Mini cover
            if let coverData = book.coverImageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 44, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            } else {
                BookCoverPlaceholder(
                    title: book.title,
                    author: book.author,
                    size: CGSize(width: 44, height: 64)
                )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .lineLimit(1)
                
                if let progress = book.readingProgress, book.importStatus == .completed {
                    ProgressView(value: progress.completedPercent)
                        .tint(SpineTokens.Colors.accentGold)
                        .scaleEffect(y: 0.6)
                }
            }
            
            Spacer()
            
            // Status badges
            if book.readingProgress?.isFinished == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.body)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            } else if book.isUpNext {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(SpineTokens.Colors.accentAmber)
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func bookContextMenu(_ book: Book) -> some View {
        if book.readingProgress?.isFinished != true {
            Button {
                book.isUpNext.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    book.isUpNext ? "Remove from Up Next" : "Add to Up Next",
                    systemImage: book.isUpNext ? "bookmark.slash" : "bookmark"
                )
            }
        }
    }
    
    // MARK: - Book Card (Grid)
    
    private func bookCard(_ book: Book) -> some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Cover
            ZStack(alignment: .topTrailing) {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                } else {
                    BookCoverPlaceholder(
                        title: book.title,
                        author: book.author,
                        size: CGSize(width: 150, height: 220)
                    )
                    .frame(height: 220)
                }
                
                // Completed badge
                if book.readingProgress?.isFinished == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                        .shadow(radius: 2)
                        .padding(SpineTokens.Spacing.xs)
                }
                
                // Up Next badge
                if book.isUpNext && book.readingProgress?.isFinished != true {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(SpineTokens.Colors.accentAmber)
                        .shadow(radius: 2)
                        .padding(SpineTokens.Spacing.xs)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                Text(book.title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress bar
            if let progress = book.readingProgress, book.importStatus == .completed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SpineTokens.Colors.warmStone.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SpineTokens.Colors.accentGold)
                            .frame(width: geo.size.width * progress.completedPercent)
                    }
                }
                .frame(height: 3)
            } else if book.importStatus != .completed {
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(book.importStatus.rawValue.capitalized)
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Empty States
    
    private var emptyLibrary: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Spacer()
            
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text("Your Library is Empty")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Import an EPUB from Project Gutenberg to start building your reading spine.")
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
            
            SpineGlassButton("Import EPUB", systemImage: "square.and.arrow.down") {
                showingFilePicker = true
            }
            
            Spacer()
        }
        .frame(minHeight: 400)
    }
    
    private var emptySegment: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            let (icon, title, subtitle) = emptySegmentContent
            
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text(title)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text(subtitle)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
        }
        .frame(minHeight: 200)
        .padding(.top, SpineTokens.Spacing.xxl)
    }
    
    private var emptySegmentContent: (String, String, String) {
        switch selectedSegment {
        case .continueReading:
            return ("book.closed", "Nothing in progress", "Start a book from your library or a reading path")
        case .upNext:
            return ("bookmark", "No books queued", "Long-press a book and tap \"Add to Up Next\"")
        case .completed:
            return ("checkmark.seal", "No classics completed yet", "Your completed works will appear here as a badge of honor")
        case .all:
            return ("books.vertical", "Library is empty", "Import a book to get started")
        case .audiobooks:
            return ("headphones", "No audiobooks yet", "Download audiobooks from the Discover tab")
        case .uploaded:
            return ("doc.badge.plus", "No uploaded books", "Import an EPUB file to get started")
        case .physicalBooks:
            return ("book.pages", "No physical books yet", "Add a book you own to start tracking")
        }
    }
    
    // MARK: - Import Overlay
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: SpineTokens.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(SpineTokens.Colors.accentGold)
                
                Text("Importing & Segmenting…")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text("Parsing chapters and creating daily reading units")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            .padding(SpineTokens.Spacing.xl)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
        }
    }
    
    // MARK: - Import Handler
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access file"
                showingError = true
                return
            }
            
            isImporting = true
            
            Task {
                defer {
                    url.stopAccessingSecurityScopedResource()
                    isImporting = false
                }
                
                do {
                    let pipeline = IngestionPipeline(modelContext: modelContext)
                    let book = try await pipeline.ingest(epubURL: url)
                    
                    // Set as active book if none set
                    if let appSettings = settings.first, appSettings.activeBookId == nil {
                        appSettings.activeBookId = book.id
                    }
                } catch {
                    importError = error.localizedDescription
                    showingError = true
                }
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }
}
