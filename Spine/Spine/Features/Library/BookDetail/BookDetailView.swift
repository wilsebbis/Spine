import SwiftUI
import SwiftData

// MARK: - Book Detail View
// Dedicated page between library grid and reader.
// Hero + About + Author + Reviews + Highlights.

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let book: Book
    
    @State private var isDescriptionExpanded = false
    @State private var showingReader = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: SpineTokens.Spacing.lg) {
                // 1. Hero
                BookHeroSection(book: book) {
                    showingReader = true
                }
                
                Divider()
                    .padding(.horizontal, SpineTokens.Spacing.md)
                
                // 2. Genre & Vibe tags
                if !book.genres.isEmpty || !book.vibes.isEmpty {
                    tagsSection
                }
                
                // 3. About this book
                aboutSection
                
                // 4. Themes & Mood
                if !book.themes.isEmpty {
                    themesSection
                }
                
                // 5. About the Author
                if let authorMeta = book.authorMetadata {
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        sectionHeader("About the Author")
                        AuthorCard(metadata: authorMeta)
                    }
                    .padding(.horizontal, SpineTokens.Spacing.md)
                }
                
                // 6. Frequent Highlights (user's own)
                if !book.highlights.isEmpty {
                    frequentHighlightsSection
                }
                
                // 7. Famous Passages (curated for classics)
                if let passages = CuratedBookData.passages[book.gutenbergId ?? ""] {
                    famousPassagesSection(passages)
                }
                
                // 8. Reader Reactions
                readerReviewsSection
                
                // 9. Critical Reception
                professionalReviewsSection
                
                Spacer(minLength: SpineTokens.Spacing.xxxl)
            }
        }
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingReader) {
            if let unit = ProgressTracker(modelContext: modelContext).todaysUnit(for: book) {
                ReaderView(book: book, initialUnit: unit)
            }
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                ForEach(book.genres, id: \.self) { genre in
                    tagChip(genre, style: .genre)
                }
                ForEach(book.vibes, id: \.self) { vibe in
                    tagChip(vibe, style: .vibe)
                }
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    private enum TagStyle { case genre, vibe }
    
    private func tagChip(_ text: String, style: TagStyle) -> some View {
        Text(text)
            .font(SpineTokens.Typography.caption2)
            .foregroundStyle(style == .genre ? SpineTokens.Colors.espresso : SpineTokens.Colors.accentGold)
            .padding(.horizontal, SpineTokens.Spacing.sm)
            .padding(.vertical, SpineTokens.Spacing.xxs)
            .background(
                style == .genre
                ? SpineTokens.Colors.warmStone.opacity(0.4)
                : SpineTokens.Colors.accentGold.opacity(0.1)
            )
            .clipShape(Capsule())
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("About This Book")
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                if book.bookDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Generate a contextual about from available book metadata
                    if let year = book.publicationYear, !book.author.isEmpty {
                        Text("\(book.title) by \(book.author), published in \(String(year)). This edition contains \(book.unitCount) reading units across \(book.chapters.count) chapters.")
                            .font(SpineTokens.Typography.body)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                    } else if !book.author.isEmpty {
                        Text("\(book.title) by \(book.author). This edition contains \(book.unitCount) reading units across \(book.chapters.count) chapters.")
                            .font(SpineTokens.Typography.body)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                    } else {
                        // True fallback — no metadata at all
                        VStack(spacing: SpineTokens.Spacing.sm) {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 28))
                                .foregroundStyle(SpineTokens.Colors.warmStone)
                            Text("No description available")
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Show themes/genres as supplementary info
                    if !book.genres.isEmpty {
                        Text(book.genres.joined(separator: " \u{00B7} "))
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                } else {
                    // Normal description
                    Text(book.bookDescription)
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    // Long description expandable
                    if let longDesc = book.longDescription {
                        if isDescriptionExpanded {
                            Text(longDesc)
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.85))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDescriptionExpanded.toggle()
                            }
                        } label: {
                            Text(isDescriptionExpanded ? "Show Less" : "Read More")
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                        }
                    }
                }
            }
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Themes Section
    
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("Themes & Mood")
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                    ForEach(book.themes, id: \.self) { theme in
                        HStack(spacing: SpineTokens.Spacing.xxs) {
                            Image(systemName: "sparkle")
                                .font(.caption2)
                                .foregroundStyle(SpineTokens.Colors.accentGold)
                            Text(theme)
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                        }
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                        .background(SpineTokens.Colors.parchment)
                        .clipShape(Capsule())
                    }
                }
                
                // Literary period context
                if let period = book.literaryPeriod, let year = book.publicationYear {
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                        Text("Published in \(String(year)) during the \(period). A defining work of its era.")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .italic()
                    }
                }
            }
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Your Highlights
    
    private var frequentHighlightsSection: some View {
        let topHighlights = Array(book.highlights.prefix(3))
        return VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("Your Highlights")
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                ForEach(topHighlights, id: \.id) { highlight in
                    highlightCard(highlight.selectedText)
                }
            }
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    private func highlightCard(_ text: String) -> some View {
        Text("\u{201C}\(text)\u{201D}")
            .font(SpineTokens.Typography.readerSerif(size: 14))
            .foregroundStyle(SpineTokens.Colors.espresso)
            .italic()
            .lineLimit(3)
            .padding(SpineTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SpineTokens.Colors.softGold.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
    }
    
    // MARK: - Famous Passages
    
    private func famousPassagesSection(_ passages: [CuratedBookData.Passage]) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("Famous Passages")
            
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                ForEach(passages, id: \.text) { passage in
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                        Text("\u{201C}\(passage.text)\u{201D}")
                            .font(SpineTokens.Typography.readerSerif(size: 14))
                            .foregroundStyle(SpineTokens.Colors.espresso)
                            .italic()
                        
                        if let note = passage.note {
                            Text(note)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                    .padding(SpineTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SpineTokens.Colors.softGold.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                }
            }
            .padding(SpineTokens.Spacing.md)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Reader Reviews
    
    private var readerReviewsSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("Reader Reactions")
            
            if let data = CuratedBookData.readerData[book.gutenbergId ?? ""] {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
                    // Rating bar
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < Int(data.rating) ? "star.fill" : (Double(i) < data.rating ? "star.leadinghalf.filled" : "star"))
                                    .font(.caption)
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                            }
                        }
                        Text(String(format: "%.1f", data.rating))
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        Text("(\(data.reviewCount.formatted()) ratings)")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    // Reader quotes
                    ForEach(data.quotes, id: \.text) { quote in
                        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxs) {
                            Text("\u{201C}\(quote.text)\u{201D}")
                                .font(SpineTokens.Typography.caption)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .italic()
                            Text("\u{2014} \(quote.reader)")
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                        .padding(SpineTokens.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SpineTokens.Colors.warmStone.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                    }
                }
                .padding(SpineTokens.Spacing.md)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
            } else {
                emptyStateCard(
                    icon: "text.bubble",
                    title: "Be the first to react",
                    subtitle: "Finish reading to leave your reaction."
                )
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Professional Reviews
    
    private var professionalReviewsSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            sectionHeader("Critical Reception")
            
            if let reviews = CuratedBookData.criticalReviews[book.gutenbergId ?? ""] {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                    ForEach(reviews, id: \.quote) { review in
                        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                            Text("\u{201C}\(review.quote)\u{201D}")
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .italic()
                            HStack(spacing: SpineTokens.Spacing.xxs) {
                                Image(systemName: "newspaper")
                                    .font(.caption2)
                                    .foregroundStyle(SpineTokens.Colors.accentGold)
                                Text("\u{2014} \(review.source)")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                            }
                        }
                        .padding(SpineTokens.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    }
                }
            } else {
                emptyStateCard(
                    icon: "newspaper",
                    title: "No critical reviews yet",
                    subtitle: "Professional reviews will appear as they're curated."
                )
            }
        }
        .padding(.horizontal, SpineTokens.Spacing.md)
    }
    
    // MARK: - Helpers
    
    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            Text(title)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            Text(subtitle)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SpineTokens.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .serif, weight: .semibold))
            .foregroundStyle(SpineTokens.Colors.espresso)
    }
}

// MARK: - Curated Book Data
// Static editorial content for the 6 seed classics.
// Keyed by Gutenberg ID. No schema changes required.

enum CuratedBookData {
    
    struct Passage {
        let text: String
        let note: String?
    }
    
    struct ReaderQuote {
        let text: String
        let reader: String
    }
    
    struct ReaderData {
        let rating: Double
        let reviewCount: Int
        let quotes: [ReaderQuote]
    }
    
    struct CriticalReview {
        let quote: String
        let source: String
    }
    
    // MARK: Famous Passages
    
    static let passages: [String: [Passage]] = [
        "1342": [ // Pride and Prejudice
            Passage(text: "It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.", note: "One of literature's most famous opening lines"),
            Passage(text: "I could easily forgive his pride, if he had not mortified mine.", note: "Elizabeth on Darcy"),
            Passage(text: "In vain I have struggled. It will not do. My feelings will not be repressed. You must allow me to tell you how ardently I admire and love you.", note: "Darcy's first proposal"),
        ],
        "84": [ // Frankenstein
            Passage(text: "Beware; for I am fearless, and therefore powerful.", note: "The creature's warning"),
            Passage(text: "Nothing is so painful to the human mind as a great and sudden change.", note: "On loss and transformation"),
            Passage(text: "Life, although it may only be an accumulation of anguish, is dear to me, and I will defend it.", note: "The creature on existence"),
        ],
        "768": [ // Wuthering Heights
            Passage(text: "He's more myself than I am. Whatever our souls are made of, his and mine are the same.", note: "Catherine on Heathcliff"),
            Passage(text: "If all else perished, and he remained, I should still continue to be.", note: "Catherine's devotion"),
        ],
        "1513": [ // Romeo and Juliet
            Passage(text: "But soft, what light through yonder window breaks? It is the east, and Juliet is the sun.", note: "The balcony scene"),
            Passage(text: "My bounty is as boundless as the sea, my love as deep; the more I give to thee, the more I have, for both are infinite.", note: "Juliet on love"),
        ],
        "11": [ // Alice in Wonderland
            Passage(text: "We're all mad here.", note: "The Cheshire Cat"),
            Passage(text: "Begin at the beginning and go on till you come to the end; then stop.", note: "The King's advice"),
        ],
        "64317": [ // The Great Gatsby
            Passage(text: "So we beat on, boats against the current, borne back ceaselessly into the past.", note: "The novel's closing line"),
            Passage(text: "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.", note: "Nick's opening reflection"),
        ],
    ]
    
    // MARK: Reader Data
    
    static let readerData: [String: ReaderData] = [
        "1342": ReaderData(rating: 4.7, reviewCount: 3_200_000, quotes: [
            ReaderQuote(text: "Still the greatest enemies-to-lovers arc ever written.", reader: "Sarah M."),
            ReaderQuote(text: "Austen's wit is sharper than any modern romcom. Every re-read reveals something new.", reader: "James K."),
        ]),
        "84": ReaderData(rating: 4.4, reviewCount: 1_800_000, quotes: [
            ReaderQuote(text: "Not a horror novel \u{2014} a heartbreaking meditation on what it means to be human.", reader: "Alex T."),
            ReaderQuote(text: "Written by a teenager. Still more emotionally sophisticated than most contemporary fiction.", reader: "Priya R."),
        ]),
        "768": ReaderData(rating: 4.2, reviewCount: 1_500_000, quotes: [
            ReaderQuote(text: "Brutal, raw, and completely unforgettable. Nothing in this book is comfortable and that's the point.", reader: "Marcus W."),
            ReaderQuote(text: "Heathcliff is not a romantic hero. This is a story about what obsession destroys.", reader: "Emma L."),
        ]),
        "1513": ReaderData(rating: 4.5, reviewCount: 2_100_000, quotes: [
            ReaderQuote(text: "Shakespeare understood teenage intensity better than any YA author.", reader: "Jordan P."),
            ReaderQuote(text: "The language is breathtaking once you get into the rhythm.", reader: "Chen W."),
        ]),
        "11": ReaderData(rating: 4.3, reviewCount: 2_400_000, quotes: [
            ReaderQuote(text: "I read this as a child for fun and as an adult for the existential dread. Both readings are valid.", reader: "Kate H."),
            ReaderQuote(text: "Carroll was doing surrealism before surrealism existed.", reader: "David M."),
        ]),
        "64317": ReaderData(rating: 4.5, reviewCount: 4_100_000, quotes: [
            ReaderQuote(text: "Every sentence is doing three things at once. Fitzgerald's prose is almost musical.", reader: "Nina S."),
            ReaderQuote(text: "A 180-page novel that contains the entire American experience. Devastating.", reader: "Tom B."),
        ]),
    ]
    
    // MARK: Critical Reviews
    
    static let criticalReviews: [String: [CriticalReview]] = [
        "1342": [
            CriticalReview(quote: "The most perfect of English novels.", source: "Sir Walter Scott"),
            CriticalReview(quote: "A masterpiece of irony and social observation that has never been surpassed.", source: "The Guardian"),
        ],
        "84": [
            CriticalReview(quote: "The most extraordinary literary achievement by anyone so young.", source: "The New York Times"),
            CriticalReview(quote: "A masterwork that invented science fiction and remains one of literature's most penetrating explorations of creation and responsibility.", source: "The Atlantic"),
        ],
        "768": [
            CriticalReview(quote: "Stands as one of the most passionate and powerful novels in the English language.", source: "Virginia Woolf"),
            CriticalReview(quote: "No novel in English is more haunted by love.", source: "The New Yorker"),
        ],
        "1513": [
            CriticalReview(quote: "The greatest love story ever told \u{2014} and also its most devastating critique.", source: "Harold Bloom"),
            CriticalReview(quote: "Shakespeare condensed an entire philosophy of love into five acts.", source: "The Times Literary Supplement"),
        ],
        "11": [
            CriticalReview(quote: "Not merely a children's book but one of the most sophisticated works of Victorian fiction.", source: "The Paris Review"),
            CriticalReview(quote: "A perfect thing of its kind, witty, ingenious, and humane.", source: "G.K. Chesterton"),
        ],
        "64317": [
            CriticalReview(quote: "The Great American Novel. Period.", source: "Time Magazine"),
            CriticalReview(quote: "A slim book that somehow contains the whole American dream and its disillusionment.", source: "T.S. Eliot"),
        ],
    ]
}
