import SwiftUI
import SwiftData

// MARK: - Highlights View
// Shows all user highlights grouped by book with search capability.

struct HighlightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Highlight.createdAt, order: .reverse) private var highlights: [Highlight]
    @Query private var books: [Book]
    
    @State private var searchText = ""
    @State private var selectedHighlight: Highlight?
    @State private var showingEdit = false
    
    private var filteredHighlights: [Highlight] {
        if searchText.isEmpty { return highlights }
        return highlights.filter {
            $0.selectedText.localizedCaseInsensitiveContains(searchText) ||
            ($0.noteText?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var highlightsByBook: [(Book, [Highlight])] {
        let grouped = Dictionary(grouping: filteredHighlights) { $0.book?.id }
        return books.compactMap { book in
            guard let bookHighlights = grouped[book.id], !bookHighlights.isEmpty else { return nil }
            return (book, bookHighlights.sorted { $0.createdAt > $1.createdAt })
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if highlights.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: SpineTokens.Spacing.lg) {
                        ForEach(highlightsByBook, id: \.0.id) { book, bookHighlights in
                            bookSection(book: book, highlights: bookHighlights)
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                    .padding(.bottom, SpineTokens.Spacing.xxl)
                }
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Highlights")
            .searchable(text: $searchText, prompt: "Search highlights & notes")
            .sheet(isPresented: $showingEdit) {
                if let highlight = selectedHighlight {
                    editHighlightSheet(highlight)
                }
            }
        }
    }
    
    // MARK: - Book Section
    
    private func bookSection(book: Book, highlights: [Highlight]) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            // Book header
            HStack(spacing: SpineTokens.Spacing.sm) {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    BookCoverPlaceholder(
                        title: book.title,
                        author: book.author,
                        size: CGSize(width: 32, height: 46)
                    )
                }
                
                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
            }
            
            // Highlights
            ForEach(highlights) { highlight in
                highlightCard(highlight)
                    .onTapGesture {
                        selectedHighlight = highlight
                        showingEdit = true
                    }
            }
        }
    }
    
    // MARK: - Highlight Card
    
    private func highlightCard(_ highlight: Highlight) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            // Highlighted text with accent bar
            HStack(alignment: .top, spacing: SpineTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: highlight.colorHex))
                    .frame(width: 3)
                
                Text(highlight.selectedText)
                    .font(SpineTokens.Typography.readerSerif(size: 15))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .lineLimit(4)
            }
            
            // Note if present
            if let note = highlight.noteText, !note.isEmpty {
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Text(note)
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .lineLimit(2)
                }
                .padding(.leading, SpineTokens.Spacing.md)
            }
            
            // Timestamp
            Text(highlight.createdAt.formatted(.relative(presentation: .named)))
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.7))
                .padding(.leading, SpineTokens.Spacing.md)
        }
        .padding(SpineTokens.Spacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    // MARK: - Edit Sheet
    
    private func editHighlightSheet(_ highlight: Highlight) -> some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.md) {
                // Quoted text
                Text(highlight.selectedText)
                    .font(SpineTokens.Typography.readerSerif(size: 16))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SpineTokens.Colors.softGold)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                
                // Note editor
                TextField("Add a note…", text: Binding(
                    get: { highlight.noteText ?? "" },
                    set: { highlight.noteText = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .font(SpineTokens.Typography.body)
                .lineLimit(3...8)
                .padding()
                .background(SpineTokens.Colors.warmStone.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                
                // Favorite toggle
                Toggle(isOn: Binding(
                    get: { highlight.isFavorite },
                    set: { highlight.isFavorite = $0 }
                )) {
                    Label("Favorite", systemImage: highlight.isFavorite ? "star.fill" : "star")
                }
                .tint(SpineTokens.Colors.accentGold)
                
                Spacer()
                
                // Delete button
                Button(role: .destructive) {
                    modelContext.delete(highlight)
                    try? modelContext.save()
                    showingEdit = false
                } label: {
                    Label("Delete Highlight", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("Edit Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        highlight.updatedAt = Date()
                        try? modelContext.save()
                        showingEdit = false
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Spacer()
            
            Image(systemName: "highlighter")
                .font(.system(size: 60))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text("No Highlights Yet")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Long-press text while reading to create highlights and capture your favorite passages.")
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
            
            Spacer()
        }
        .frame(minHeight: 400)
    }
}
