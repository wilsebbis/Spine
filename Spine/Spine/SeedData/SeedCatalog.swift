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
        let gutenbergId: String
        let language: String
        let bundleFilename: String
        let genres: [String]
        let vibes: [String]
    }
    
    static let books: [SeedBook] = [
        SeedBook(
            title: "Pride and Prejudice",
            author: "Jane Austen",
            description: "A witty exploration of love, reputation, and class in Regency England.",
            gutenbergId: "1342",
            language: "en",
            bundleFilename: "PrideAndPrejudice.epub",
            genres: ["Romance", "Literary Fiction", "Drama"],
            vibes: ["Witty", "Atmospheric", "Strong characters"]
        ),
        SeedBook(
            title: "Frankenstein; Or, The Modern Prometheus",
            author: "Mary Shelley",
            description: "A young scientist creates a grotesque creature in an unorthodox experiment.",
            gutenbergId: "84",
            language: "en",
            bundleFilename: "Frankenstein.epub",
            genres: ["Horror", "Sci-Fi", "Literary Fiction"],
            vibes: ["Dark", "Philosophical", "Atmospheric", "Emotional"]
        ),
        SeedBook(
            title: "Wuthering Heights",
            author: "Emily Brontë",
            description: "A tale of consuming passion and revenge on the Yorkshire moors.",
            gutenbergId: "768",
            language: "en",
            bundleFilename: "WutheringHeights.epub",
            genres: ["Romance", "Drama", "Literary Fiction"],
            vibes: ["Dark", "Atmospheric", "Emotional", "Strong characters"]
        ),
        SeedBook(
            title: "Alice's Adventures in Wonderland",
            author: "Lewis Carroll",
            description: "A young girl falls down a rabbit hole into a fantastical underground world.",
            gutenbergId: "11",
            language: "en",
            bundleFilename: "AliceInWonderland.epub",
            genres: ["Fantasy", "Humor", "Adventure"],
            vibes: ["Experimental", "Witty", "Fast-paced"]
        ),
        SeedBook(
            title: "Romeo and Juliet",
            author: "William Shakespeare",
            description: "Two young lovers from feuding families in Verona pursue their forbidden romance.",
            gutenbergId: "1513",
            language: "en",
            bundleFilename: "RomeoAndJuliet.epub",
            genres: ["Drama", "Romance", "Poetry"],
            vibes: ["Emotional", "Dark", "Beautiful prose"]
        ),
        SeedBook(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            description: "A mysterious millionaire's obsessive pursuit of a lost love amid the decadence of the Jazz Age.",
            gutenbergId: "64317",
            language: "en",
            bundleFilename: "TheGreatGatsby.epub",
            genres: ["Literary Fiction", "Drama"],
            vibes: ["Atmospheric", "Beautiful prose", "Dark", "Emotional"]
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
        guard existingCount == 0 else { return }
        
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
    }
}
