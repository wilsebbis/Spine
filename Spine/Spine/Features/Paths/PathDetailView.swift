import SwiftUI
import SwiftData

// MARK: - Path Detail View
// Full path page: why this path exists, what books are included,
// how far along you are, and a clear "Start" or "Continue" CTA.
// Answers: "What am I committing to and why should I care?"

struct PathDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    
    let path: ReadingPath
    
    @State private var showingReader = false
    @State private var activeBook: Book?
    
    private var pathBooks: [Book] {
        path.bookIds.compactMap { bookId in
            books.first { $0.id == bookId }
        }
    }
    
    private var progress: Double { path.progress(books: books) }
    private var isStarted: Bool { path.isStarted(books: books) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: SpineTokens.Spacing.lg) {
                // Path header
                headerSection
                
                // Progress (if started)
                if isStarted {
                    progressSection
                }
                
                // Description
                descriptionSection
                
                // Books in this path
                booksSection
                
                // Start / Continue CTA
                ctaSection
            }
            .padding(.horizontal, SpineTokens.Spacing.md)
            .padding(.bottom, SpineTokens.Spacing.xxl)
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingReader) {
            if let book = activeBook,
               let unit = book.sortedUnits.first(where: { !$0.isCompleted }) {
                ReaderView(book: book, initialUnit: unit)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Path icon (large)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold).opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold,
                                (Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: path.iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: (Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold).opacity(0.4), radius: 12)
            }
            
            VStack(spacing: SpineTokens.Spacing.xs) {
                Text(path.title)
                    .font(SpineTokens.Typography.largeTitle)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Text(path.subtitle)
                    .font(SpineTokens.Typography.callout)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
            }
            
            // Metadata pills
            HStack(spacing: SpineTokens.Spacing.sm) {
                metadataPill(path.difficulty.emoji + " " + path.difficulty.rawValue)
                metadataPill("📚 \(path.bookIds.count) books")
                metadataPill("📅 ~\(path.estimatedWeeks) weeks")
            }
        }
        .padding(.top, SpineTokens.Spacing.md)
    }
    
    private func metadataPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(SpineTokens.Colors.espresso)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SpineTokens.Colors.warmStone.opacity(0.15))
            .clipShape(Capsule())
    }
    
    // MARK: - Progress
    
    private var progressSection: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            HStack {
                Text("Path Progress")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SpineTokens.Colors.warmStone.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(path.booksFinished(books: books)) of \(path.bookIds.count) books completed")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Description
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("About This Path")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text(path.pathDescription)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.85))
                .lineSpacing(4)
        }
        .padding(SpineTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Books
    
    private var booksSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Books in This Path")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            ForEach(Array(pathBooks.enumerated()), id: \.element.id) { index, book in
                pathBookRow(book: book, index: index + 1)
            }
        }
    }
    
    private func pathBookRow(book: Book, index: Int) -> some View {
        let isFinished = book.readingProgress?.isFinished == true
        let progress = book.readingProgress?.completedPercent ?? 0
        
        return HStack(spacing: SpineTokens.Spacing.md) {
            // Step number / check
            ZStack {
                Circle()
                    .fill(isFinished ? SpineTokens.Colors.successGreen : SpineTokens.Colors.warmStone.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                if isFinished {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(SpineTokens.Colors.espresso)
                }
            }
            
            // Cover
            if let coverData = book.coverImageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                BookCoverPlaceholder(
                    title: book.title,
                    author: book.author,
                    size: CGSize(width: 40, height: 58)
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
                
                if progress > 0 && !isFinished {
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
                }
            }
            
            Spacer()
            
            if isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SpineTokens.Colors.successGreen)
            } else if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold)
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    // MARK: - CTA
    
    private var ctaSection: some View {
        Button {
            if let next = path.nextBook(books: books) {
                activeBook = next
                showingReader = true
            }
        } label: {
            HStack {
                Image(systemName: isStarted ? "arrow.right" : "play.fill")
                Text(isStarted ? "Continue Path" : "Start This Path")
                    .font(SpineTokens.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpineTokens.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold,
                        (Color(hex: path.themeColorHex) ?? SpineTokens.Colors.accentGold).opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
    }
}
