import SwiftUI
import SwiftData

// MARK: - Reading Diary View
// A high-fidelity visual grid of logged/completed books.

struct ReadingDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Book> { book in
            book.readingProgress?.completedPercent ?? 0 >= 1.0 || book.readingProgress?.finishedAt != nil
        },
        sort: \Block.title // We'll sort manually to avoid SwiftData #Predicate issues with nested optionals
    ) private var finishedBooksData: [Book]
    
    // Sort manually by finishedAt (descending)
    private var finishedBooks: [Book] {
        finishedBooksData.sorted {
            let d1 = $0.readingProgress?.finishedAt ?? Date.distantPast
            let d2 = $1.readingProgress?.finishedAt ?? Date.distantPast
            return d1 > d2
        }
    }
    
    // Group books by year
    private var groupedBooks: [(year: String, books: [Book])] {
        let sorted = finishedBooks
        var dict: [String: [Book]] = [:]
        
        for book in sorted {
            let date = book.readingProgress?.finishedAt ?? book.readingProgress?.lastReadAt ?? Date()
            let year = Calendar.current.component(.year, from: date)
            dict[String(year), default: []].append(book)
        }
        
        return dict.map { (year: $0.key, books: $0.value) }.sorted { $0.year > $1.year }
    }
    
    @State private var selectedBook: Book?
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: SpineTokens.Spacing.sm)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: SpineTokens.Spacing.xl) {
                
                // Header Stats
                HStack(spacing: SpineTokens.Spacing.xl) {
                    VStack {
                        Text("\(finishedBooks.count)")
                            .font(SpineTokens.Typography.display)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("Total Books")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    let thisYearCount = groupedBooks.first(where: { $0.year == String(Calendar.current.component(.year, from: Date())) })?.books.count ?? 0
                    
                    VStack {
                        Text("\(thisYearCount)")
                            .font(SpineTokens.Typography.display)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("This Year")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
                .padding(.top, SpineTokens.Spacing.lg)
                
                if finishedBooks.isEmpty {
                    VStack(spacing: SpineTokens.Spacing.md) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 48))
                            .foregroundStyle(SpineTokens.Colors.warmStone)
                        Text("Your reading diary is empty.")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("Books you finish reading will appear here, allowing you to rate and review them.")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 60)
                } else {
                    // Grouped Grid
                    ForEach(groupedBooks, id: \.year) { group in
                        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                            Text(group.year)
                                .font(SpineTokens.Typography.headline)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            
                            LazyVGrid(columns: columns, spacing: SpineTokens.Spacing.md) {
                                ForEach(group.books) { book in
                                    DiaryBookCard(book: book)
                                        .onTapGesture {
                                            selectedBook = book
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                }
            }
            .padding(.bottom, SpineTokens.Spacing.xxl)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationTitle("Reading Diary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBook) { book in
            ReviewEditorView(book: book)
        }
    }
}

// MARK: - Diary Book Card
// Displays the cover and star rating for a completed book.

struct DiaryBookCard: View {
    let book: Book
    
    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let coverData = book.coverImageData, let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    BookCoverPlaceholder(title: book.title, author: book.author, size: CGSize(width: 100, height: 150))
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            // Rating stars
            if let rating = book.readingProgress?.rating, rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(i <= rating ? SpineTokens.Colors.accentGold : SpineTokens.Colors.subtleGray.opacity(0.3))
                    }
                }
                .padding(.top, 2)
            } else {
                Text("Tap to rate")
                    .font(.system(size: 10))
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .padding(.top, 2)
            }
        }
    }
}
