import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Library View
// Shows all imported books with cover art, progress, and import capability.

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Query private var settings: [UserSettings]
    
    @State private var showingFilePicker = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var searchText = ""
    @State private var selectedBook: Book?
    @State private var showingReader = false
    
    private var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: SpineTokens.Spacing.md)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if books.isEmpty {
                    emptyLibrary
                } else {
                    // For You recommendations
                    ForYouView()
                    
                    LazyVGrid(columns: columns, spacing: SpineTokens.Spacing.md) {
                        ForEach(filteredBooks) { book in
                            bookCard(book)
                                .onTapGesture {
                                    selectedBook = book
                                    showingReader = true
                                }
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                    .padding(.bottom, SpineTokens.Spacing.xxl)
                }
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)
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
            .navigationDestination(isPresented: $showingReader) {
                if let book = selectedBook {
                    let unit = ProgressTracker(modelContext: modelContext).todaysUnit(for: book)
                    if let unit {
                        ReaderView(book: book, initialUnit: unit)
                    }
                }
            }
        }
    }
    
    // MARK: - Book Card
    
    private func bookCard(_ book: Book) -> some View {
        VStack(spacing: SpineTokens.Spacing.xs) {
            // Cover
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
    
    // MARK: - Empty State
    
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
