import Foundation
import SwiftData

// MARK: - Seed Catalog
// Provides starter book metadata for the library.
// Auto-ingests bundled EPUBs on first launch.

struct SeedCatalog {
    
    struct SeedBook {
        let title: String
        let author: String
        let description: String
        let longDescription: String
        let gutenbergId: String
        let language: String
        let bundleFilename: String
        let genres: [String]
        let vibes: [String]
        let themes: [String]
        let publicationYear: Int
        let literaryPeriod: String
        let authorMetadata: AuthorMetadata
    }
    
    static let books: [SeedBook] = [
        SeedBook(
            title: "Pride and Prejudice",
            author: "Jane Austen",
            description: "A witty exploration of love, reputation, and class in Regency England.",
            longDescription: "When Elizabeth Bennet meets the seemingly arrogant Mr. Darcy at a country ball, their mutual prejudice sets the stage for one of literature's most beloved romances. As the Bennet sisters navigate the marriage market of Regency England—where a family's future depends on advantageous matches—Elizabeth must reconcile her sharp first impressions with deeper truths about character, pride, and genuine feeling. Through a gallery of unforgettable characters, from the scheming Mrs. Bennet to the insufferable Mr. Collins, Austen delivers a razor-sharp comedy of manners that remains startlingly modern in its observations about love, class, and the courage it takes to change your mind.",
            gutenbergId: "1342",
            language: "en",
            bundleFilename: "PrideAndPrejudice.epub",
            genres: ["Romance", "Literary Fiction", "Drama"],
            vibes: ["Witty", "Atmospheric", "Strong characters"],
            themes: ["Class", "Marriage", "Reputation", "First impressions", "Female autonomy"],
            publicationYear: 1813,
            literaryPeriod: "Regency era",
            authorMetadata: AuthorMetadata(
                name: "Jane Austen",
                birthYear: 1775,
                deathYear: 1817,
                nationality: "English",
                shortBio: "Jane Austen is one of the most widely read English novelists in history. Writing during the Regency period, she perfected the comedy of manners with her sharp social observation and psychological insight. Her six completed novels have never gone out of print.",
                notableWorks: ["Sense and Sensibility", "Pride and Prejudice", "Mansfield Park", "Emma", "Northanger Abbey", "Persuasion"]
            )
        ),
        SeedBook(
            title: "Frankenstein; Or, The Modern Prometheus",
            author: "Mary Shelley",
            description: "A young scientist creates a grotesque creature in an unorthodox experiment.",
            longDescription: "Victor Frankenstein, a brilliant and obsessive young scientist, discovers the secret of animating dead matter and creates a living being from assembled body parts. Horrified by his creation, he abandons it—setting in motion a chain of tragedy, murder, and remorse that pursues him from the laboratories of Ingolstadt to the frozen Arctic. Told through a frame of letters and confessions, this novel explores ambition without responsibility, the pain of rejection, and the catastrophic consequences of playing God. Written by a nineteen-year-old Mary Shelley during a legendary ghost-story competition, it remains the founding text of science fiction and one of the most haunting meditations on creation ever written.",
            gutenbergId: "84",
            language: "en",
            bundleFilename: "Frankenstein.epub",
            genres: ["Horror", "Sci-Fi", "Literary Fiction"],
            vibes: ["Dark", "Philosophical", "Atmospheric", "Emotional"],
            themes: ["Ambition", "Creation", "Isolation", "Responsibility", "Monstrousness"],
            publicationYear: 1818,
            literaryPeriod: "Romantic era",
            authorMetadata: AuthorMetadata(
                name: "Mary Shelley",
                birthYear: 1797,
                deathYear: 1851,
                nationality: "English",
                shortBio: "Mary Shelley was an English novelist who created Frankenstein at age nineteen during a stormy summer at Lake Geneva. The daughter of philosopher William Godwin and feminist Mary Wollstonecraft, she was immersed in radical intellectual circles. Her novel is widely considered the first work of science fiction.",
                notableWorks: ["Frankenstein", "The Last Man", "Mathilda", "Valperga"]
            )
        ),
        SeedBook(
            title: "Wuthering Heights",
            author: "Emily Brontë",
            description: "A tale of consuming passion and revenge on the Yorkshire moors.",
            longDescription: "On the wild Yorkshire moors, the foundling Heathcliff and Catherine Earnshaw form a bond so intense it transcends every social boundary—and ultimately destroys everyone around them. After Catherine chooses respectability over passion by marrying Edgar Linton, Heathcliff's love curdles into a decades-long campaign of revenge against two families. Narrated through the unreliable filter of servants and tenants, the story unfolds like a storm: violent, beautiful, and utterly uncontrollable. Emily Brontë's only novel shocked Victorian readers with its raw emotional power and remains one of literature's most passionate and disturbing love stories.",
            gutenbergId: "768",
            language: "en",
            bundleFilename: "WutheringHeights.epub",
            genres: ["Romance", "Drama", "Literary Fiction"],
            vibes: ["Dark", "Atmospheric", "Emotional", "Strong characters"],
            themes: ["Obsessive love", "Revenge", "Social class", "Nature vs. civilization", "The supernatural"],
            publicationYear: 1847,
            literaryPeriod: "Victorian era",
            authorMetadata: AuthorMetadata(
                name: "Emily Brontë",
                birthYear: 1818,
                deathYear: 1848,
                nationality: "English",
                shortBio: "Emily Brontë was an English novelist and poet, best known for her only novel Wuthering Heights. She lived a reclusive life on the Yorkshire moors with her literary sisters Charlotte and Anne. She died of tuberculosis at thirty, just a year after her masterpiece was published.",
                notableWorks: ["Wuthering Heights", "Poems by Currer, Ellis, and Acton Bell"]
            )
        ),
        SeedBook(
            title: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            description: "A young girl falls down a rabbit hole into a fantastical underground world.",
            longDescription: "When Alice follows a White Rabbit down a rabbit hole, she tumbles into a world where nothing makes sense—and everything makes a strange kind of sense. She grows and shrinks, attends a mad tea party, plays croquet with flamingos, and faces trial before a murderous Queen of Hearts. Carroll's masterpiece functions on multiple levels: a delightful children's adventure, a satire of Victorian manners, a playground of mathematical logic, and an exploration of the absurdity of adult rules seen through a child's clear eyes. Its surreal imagery and wordplay have influenced everything from modernist literature to psychedelia.",
            gutenbergId: "11",
            language: "en",
            bundleFilename: "AliceInWonderland.epub",
            genres: ["Fantasy", "Humor", "Adventure"],
            vibes: ["Experimental", "Witty", "Fast-paced"],
            themes: ["Identity", "Logic vs. absurdity", "Growing up", "Language and meaning", "Authority"],
            publicationYear: 1865,
            literaryPeriod: "Victorian era",
            authorMetadata: AuthorMetadata(
                name: "Lewis Carroll",
                birthYear: 1832,
                deathYear: 1898,
                nationality: "English",
                shortBio: "Lewis Carroll was the pen name of Charles Lutwidge Dodgson, an Oxford mathematics lecturer who wrote two of the most famous children's books in English. His works blend logic puzzles, wordplay, and surreal fantasy. He was also a pioneering amateur photographer.",
                notableWorks: ["Alice's Adventures in Wonderland", "Through the Looking-Glass", "The Hunting of the Snark", "Sylvie and Bruno"]
            )
        ),
        SeedBook(
            title: "Romeo and Juliet",
            author: "William Shakespeare",
            description: "Two young lovers from feuding families in Verona pursue their forbidden romance.",
            longDescription: "In Verona, the ancient feud between the Montagues and Capulets erupts into street violence. When Romeo Montague and Juliet Capulet meet at a masked ball, they fall instantly and irrevocably in love. What follows is literature's most famous five-day romance—a whirlwind of secret marriage, banishment, desperate schemes, and fatal misunderstanding that ends in the lovers' deaths and their families' belated reconciliation. Shakespeare's most popular play blends lyric poetry, bawdy comedy, and devastating tragedy into a work that has defined romantic love in the Western imagination for over four centuries.",
            gutenbergId: "1513",
            language: "en",
            bundleFilename: "RomeoAndJuliet.epub",
            genres: ["Drama", "Romance", "Poetry"],
            vibes: ["Emotional", "Dark", "Beautiful prose"],
            themes: ["Forbidden love", "Fate", "Family loyalty", "Youth vs. age", "Violence"],
            publicationYear: 1597,
            literaryPeriod: "Elizabethan era",
            authorMetadata: AuthorMetadata(
                name: "William Shakespeare",
                birthYear: 1564,
                deathYear: 1616,
                nationality: "English",
                shortBio: "William Shakespeare is widely regarded as the greatest writer in the English language. A playwright, poet, and actor from Stratford-upon-Avon, he produced at least 37 plays and 154 sonnets that have been translated into every living language. His works invented thousands of English words still in use today.",
                notableWorks: ["Hamlet", "Macbeth", "Othello", "King Lear", "A Midsummer Night's Dream", "The Tempest"]
            )
        ),
        SeedBook(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            description: "A mysterious millionaire's obsessive pursuit of a lost love amid the decadence of the Jazz Age.",
            longDescription: "In the summer of 1922, the young bond salesman Nick Carraway rents a cottage on Long Island next to the lavish mansion of Jay Gatsby—a self-made millionaire who throws legendary parties for people he doesn't know. Nick is drawn into Gatsby's orbit and learns the truth behind the spectacle: everything Gatsby has built is a monument to his lost love for Daisy Buchanan, Nick's cousin. As the summer reaches its climax, the collision between old money, new money, and no money at all leads to a tragedy that exposes the hollow core of the American Dream. Fitzgerald's masterpiece is the definitive novel of ambition, reinvention, and the impossibility of recapturing the past.",
            gutenbergId: "64317",
            language: "en",
            bundleFilename: "TheGreatGatsby.epub",
            genres: ["Literary Fiction", "Drama"],
            vibes: ["Atmospheric", "Beautiful prose", "Dark", "Emotional"],
            themes: ["The American Dream", "Wealth and class", "Obsessive love", "Reinvention", "Moral decay"],
            publicationYear: 1925,
            literaryPeriod: "Jazz Age / Modernism",
            authorMetadata: AuthorMetadata(
                name: "F. Scott Fitzgerald",
                birthYear: 1896,
                deathYear: 1940,
                nationality: "American",
                shortBio: "F. Scott Fitzgerald was an American novelist and short story writer whose works defined the Jazz Age. His prose style—lyric, precise, and suffused with longing—is among the most celebrated in American literature. He died at forty-four, believing himself a failure; The Great Gatsby is now considered the Great American Novel.",
                notableWorks: ["The Great Gatsby", "Tender Is the Night", "This Side of Paradise", "The Beautiful and Damned"]
            )
        ),
    ]
    
    /// Find a bundled EPUB by filename.
    private static func findBundledEPUB(filename: String) -> URL? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        
        // Strategy 1: Flat bundle
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        // Strategy 2: Subdirectory "Resources" (folder reference)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources") {
            return url
        }
        // Strategy 3: Recursive search
        if let bundlePath = Bundle.main.resourcePath {
            let fm = FileManager.default
            if let enumerator = fm.enumerator(atPath: bundlePath) {
                while let path = enumerator.nextObject() as? String {
                    if path.hasSuffix(filename) {
                        return URL(fileURLWithPath: bundlePath).appendingPathComponent(path)
                    }
                }
            }
        }
        return nil
    }
    
    /// Seed the database with starter catalog if empty.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Book>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        
        if existingCount == 0 {
            print("📚 Seeding catalog with \(books.count) books...")
            
            for seed in books {
                let book = Book(
                    title: seed.title,
                    author: seed.author,
                    bookDescription: seed.description,
                    sourceType: .gutenberg,
                    language: seed.language,
                    gutenbergId: seed.gutenbergId
                )
                book.importStatus = .pending
                book.genres = seed.genres
                book.vibes = seed.vibes
                book.themes = seed.themes
                book.longDescription = seed.longDescription
                book.publicationYear = seed.publicationYear
                book.literaryPeriod = seed.literaryPeriod
                book.authorMetadata = seed.authorMetadata
                
                if let bundleURL = findBundledEPUB(filename: seed.bundleFilename) {
                    book.localFileURI = bundleURL.path
                    print("📚 Found bundled EPUB: \(seed.bundleFilename) → \(bundleURL.path)")
                } else {
                    print("📚 ⚠️ Bundled EPUB NOT found: \(seed.bundleFilename)")
                }
                
                modelContext.insert(book)
            }
            
            try? modelContext.save()
            print("📚 Seed complete.")
        }
        
        // Always run — has its own deduplication via gutenbergId check
        DiscoverCatalog.seedIfNeeded(modelContext: modelContext)
        
        // Seed paths after all books exist
        seedPathsIfNeeded(modelContext: modelContext)
    }
    
    /// Seed curated reading paths. Matches books by title.
    @MainActor
    static func seedPathsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ReadingPath>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }
        
        let bookDescriptor = FetchDescriptor<Book>()
        guard let allBooks = try? modelContext.fetch(bookDescriptor) else { return }
        
        func bookIdsByTitles(_ titles: [String]) -> [UUID] {
            titles.compactMap { title in
                allBooks.first(where: { $0.title.localizedCaseInsensitiveContains(title) })?.id
            }
        }
        
        let paths: [(String, String, String, String, String, ReadingPath.Difficulty, Int, [String])] = [
            (
                "Starter Classics",
                "Short, accessible books to build your reading habit",
                "The perfect starting point. These shorter classics are approachable, engaging, and will give you the confidence to keep going. Finish your first book in days, not months.",
                "star.fill",
                "4CAF50",
                .beginner,
                3,
                ["The Great Gatsby", "Alice", "Candide", "Heart of Darkness"]
            ),
            (
                "Greek Foundations",
                "The epics and dialogues that built Western thought",
                "Start where civilization started. Homer's epic heroes, Plato's relentless questioning, and the birth of democracy—these are the texts that every later classic is in conversation with.",
                "building.columns.fill",
                "5C6BC0",
                .intermediate,
                12,
                ["Iliad", "Odyssey", "Republic", "Symposium", "Apology", "Nicomachean Ethics"]
            ),
            (
                "Shakespeare Essential",
                "The five plays everyone should read",
                "Shakespeare wrote for the cheap seats—fast, funny, bloody, and unforgettable. These are shorter than you think and more dramatic than anything streaming. Read one a week.",
                "theatermasks.fill",
                "FF5722",
                .intermediate,
                5,
                ["Hamlet", "Macbeth", "Othello", "King Lear", "Tempest"]
            ),
            (
                "Love & Society",
                "Romance, class, and the games people play",
                "Fall in love with love—and the sharp social observations that surround it. These classics explore courtship, reputation, and the courage it takes to choose your own path.",
                "heart.fill",
                "E91E63",
                .beginner,
                8,
                ["Pride and Prejudice", "Romeo and Juliet", "Anna Karenina", "Middlemarch"]
            ),
            (
                "Monsters & Gothic",
                "Dark tales of creation, obsession, and the supernatural",
                "The original horror stories that invented entire genres. From Shelley's creature to Brontë's moors, these novels explore what happens when ambition, desire, and nature collide in the dark.",
                "moon.stars.fill",
                "9C27B0",
                .intermediate,
                6,
                ["Frankenstein", "Wuthering Heights", "Heart of Darkness"]
            ),
            (
                "Epic Poetry",
                "The grandest stories ever told in verse",
                "From Troy to Hell to Paradise—these are the biggest, most ambitious poems in human history. Each one defined an entire civilization's sense of itself.",
                "flame.fill",
                "FF6D00",
                .advanced,
                20,
                ["Iliad", "Odyssey", "Aeneid", "Divine Comedy", "Paradise Lost"]
            ),
            (
                "Philosophy Core",
                "The essential questions: justice, knowledge, the good life",
                "What is real? What is good? How should you live? These texts don't answer your questions—they change the questions you ask.",
                "lightbulb.fill",
                "FFC107",
                .advanced,
                16,
                ["Apology", "Republic", "Nicomachean Ethics", "Meditations", "Leviathan", "Discourse on the Method", "Critique of Pure Reason"]
            ),
            (
                "Fathers of History",
                "How we learned to tell our own story",
                "Before these writers, the past was myth. After them, it became something you could investigate, argue about, and learn from. These are the founders of history as a discipline.",
                "scroll.fill",
                "795548",
                .advanced,
                14,
                ["History of Herodotus", "Peloponnesian War", "Plutarch", "Decline and Fall"]
            ),
            (
                "Science Revolution",
                "The discoveries that changed everything",
                "Darwin on evolution, Newton on light, Harvey on the heart—these are the original papers and books that overturned centuries of assumption and built the modern world.",
                "atom",
                "00BCD4",
                .advanced,
                10,
                ["Origin of Species", "On the Nature of Things", "Opticks", "Dialogues Concerning Two New Sciences"]
            ),
            (
                "Dark Psychology",
                "Obsession, revenge, and the human mind at its extremes",
                "Venture into the most psychologically intense literature ever written. These books don't just tell stories—they make you question what you'd do under impossible pressure.",
                "brain.head.profile",
                "D32F2F",
                .advanced,
                12,
                ["Crime and Punishment", "Brothers Karamazov", "Moby Dick", "Frankenstein"]
            ),
            (
                "Political Thought",
                "Power, freedom, and how societies organize themselves",
                "From Machiavelli's cunning prince to Mill's defense of liberty—these are the texts that kings, revolutionaries, and founders read before making history.",
                "building.2.fill",
                "1565C0",
                .advanced,
                10,
                ["Prince", "Leviathan", "Social Contract", "On Liberty", "Federalist", "Communist Manifesto"]
            ),
            (
                "The Russian Soul",
                "Tolstoy, Dostoevsky, and the deepest questions",
                "No literature goes deeper into guilt, redemption, faith, and the human condition. These novels are long—but they will change how you see people forever.",
                "snowflake",
                "42A5F5",
                .advanced,
                20,
                ["War and Peace", "Brothers Karamazov", "Crime and Punishment", "Anna Karenina"]
            ),
        ]
        
        for (index, p) in paths.enumerated() {
            let path = ReadingPath(
                title: p.0,
                subtitle: p.1,
                description: p.2,
                iconName: p.3,
                themeColorHex: p.4,
                difficulty: p.5,
                estimatedWeeks: p.6,
                sortOrder: index,
                bookIds: bookIdsByTitles(p.7)
            )
            modelContext.insert(path)
        }
        
        try? modelContext.save()
        print("📚 Seeded \(paths.count) reading paths")
    }
    
    /// Ingest all un-ingested bundled EPUBs.
    @MainActor
    static func ingestBundledBooks(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? modelContext.fetch(descriptor) else {
            print("📚 ⚠️ Could not fetch books for ingestion")
            return
        }
        
        // Debug: log status of all books
        for book in allBooks {
            print("📚 Book '\(book.title)' — status: \(book.importStatus.rawValue), hasURI: \(book.localFileURI != nil), chapters: \(book.chapters.count)")
        }
        
        // Find books that need ingestion: not completed or have no chapters
        let needsIngestion = allBooks.filter { $0.importStatus != .completed || $0.chapters.isEmpty }
        
        // Try to find bundled EPUBs for books missing a localFileURI
        for book in needsIngestion where book.localFileURI == nil {
            // Match by gutenbergId first, then by title
            let seed = books.first(where: { $0.gutenbergId == book.gutenbergId })
                     ?? books.first(where: { $0.title == book.title })
            if let seed = seed, let bundleURL = findBundledEPUB(filename: seed.bundleFilename) {
                book.localFileURI = bundleURL.path
                book.importStatus = .pending
                // Also backfill enrichment data if missing
                if book.longDescription == nil { book.longDescription = seed.longDescription }
                if book.themes.isEmpty { book.themes = seed.themes }
                if book.publicationYear == nil { book.publicationYear = seed.publicationYear }
                if book.literaryPeriod == nil { book.literaryPeriod = seed.literaryPeriod }
                if book.authorMetadata == nil { book.authorMetadata = seed.authorMetadata }
                print("📚 Matched EPUB for '\(book.title)': \(bundleURL.path)")
            }
        }
        try? modelContext.save()
        
        let readyBooks = needsIngestion.filter { $0.localFileURI != nil }
        print("📚 Ready to ingest: \(readyBooks.count) books")
        
        guard !readyBooks.isEmpty else { return }
        
        let pipeline = IngestionPipeline(modelContext: modelContext)
        
        for book in readyBooks {
            guard let localPath = book.localFileURI else { continue }
            let url = URL(fileURLWithPath: localPath)
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("📚 ⚠️ File not found: \(localPath)")
                book.importStatus = .failed
                book.importError = "EPUB not found at \(localPath)"
                continue
            }
            
            do {
                let title = book.title
                modelContext.delete(book)
                try? modelContext.save()
                
                print("📚 Ingesting: \(title)...")
                _ = try await pipeline.ingest(epubURL: url)
                print("📚 ✅ Ingested: \(title)")
            } catch {
                print("📚 ❌ Ingestion failed: \(error.localizedDescription)")
            }
        }
        
        // After ingestion, backfill enrichment data
        enrichExistingBooks(modelContext: modelContext)
    }
    
    /// Backfill enrichment data from seed catalog to existing books.
    /// Matches by title (case-insensitive). Safe to call multiple times.
    @MainActor
    static func enrichExistingBooks(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? modelContext.fetch(descriptor) else { return }
        
        var enriched = 0
        for book in allBooks {
            // Match by title (case-insensitive, trimmed)
            guard let seed = books.first(where: {
                $0.title.localizedCaseInsensitiveCompare(book.title) == .orderedSame
            }) else { continue }
            
            // Backfill missing fields
            if book.longDescription == nil || book.longDescription?.isEmpty == true {
                book.longDescription = seed.longDescription
            }
            if book.themes.isEmpty {
                book.themes = seed.themes
            }
            if book.genres.isEmpty {
                book.genres = seed.genres
            }
            if book.vibes.isEmpty {
                book.vibes = seed.vibes
            }
            if book.publicationYear == nil {
                book.publicationYear = seed.publicationYear
            }
            if book.literaryPeriod == nil {
                book.literaryPeriod = seed.literaryPeriod
            }
            if book.authorMetadata == nil {
                book.authorMetadata = seed.authorMetadata
            }
            if book.gutenbergId == nil || book.gutenbergId?.isEmpty == true {
                book.gutenbergId = seed.gutenbergId
            }
            // Fix junk descriptions
            // Fix junk descriptions — replace with seed data
            let sanitized = IngestionPipeline.sanitizeDescription(book.bookDescription)
            if sanitized.isEmpty {
                book.bookDescription = seed.description
            }
            
            enriched += 1
        }
        
        if enriched > 0 {
            try? modelContext.save()
            print("📚 Enriched \(enriched) books with seed catalog data")
        }
    }
}
