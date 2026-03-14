import Foundation

// MARK: - Gutenberg Catalog (JSON-driven)
// Loads the full Gutenberg category index from gutenberg_catalog.json
// and LibriVox match data from librivox_matches.json at app launch.
// This replaces the old hand-curated 274-entry DiscoverCatalog.

// MARK: - JSON Models

struct GutenbergCatalogSection: Codable, Identifiable {
    let section: String
    let categories: [GutenbergCatalogCategory]
    var id: String { section }
}

struct GutenbergCatalogCategory: Codable, Identifiable {
    let name: String
    let bookshelf_id: Int
    let books: [GutenbergCatalogBook]
    var id: Int { bookshelf_id }
}

struct GutenbergCatalogBook: Codable, Identifiable, Hashable {
    let ebook_id: Int
    let title: String
    let author: String
    let epub3_url: String
    let cover_url: String
    var id: Int { ebook_id }
    
    var gutenbergId: String { String(ebook_id) }
}

// MARK: - LibriVox Match Data

struct LibriVoxMatchData: Codable {
    let total_librivox_audiobooks: Int
    let total_gutenberg_unique: Int
    let total_matches: Int
    let matched_ebook_ids: [Int]
    let matches: [LibriVoxMatch]
}

struct LibriVoxMatch: Codable {
    let ebook_id: Int
    let gutenberg_title: String
    let librivox_title: String
    let librivox_url: String
    let total_time: String
    let total_time_secs: Int
}

// MARK: - Catalog Manager

final class GutenbergCatalogManager {
    static let shared = GutenbergCatalogManager()
    
    /// All sections/categories loaded from JSON
    private(set) var sections: [GutenbergCatalogSection] = []
    
    /// Set of ebook IDs that have LibriVox recordings
    private(set) var librivoxIds: Set<Int> = []
    
    /// LibriVox match details (title, url, duration)
    private(set) var librivoxMatches: [Int: LibriVoxMatch] = [:]
    
    /// All unique books (deduped by ebook_id)
    private(set) var allBooks: [GutenbergCatalogBook] = []
    
    /// All books with LibriVox recordings
    var audiobookCatalog: [GutenbergCatalogBook] {
        allBooks.filter { librivoxIds.contains($0.ebook_id) }
    }
    
    /// Sections/categories containing ONLY audiobook entries
    private(set) var audiobookSections: [GutenbergCatalogSection] = []
    
    /// Map: ebook_id → [category names] the book appears in
    private(set) var bookCategories: [Int: [String]] = [:]
    
    /// Search corpus for NL matching: ebook_id → "Title by Author | Category1, Category2"
    private(set) var searchCorpus: [Int: String] = [:]
    
    /// Quick counts
    var totalBooks: Int { allBooks.count }
    var totalAudiobooks: Int { librivoxIds.count }
    var totalCategories: Int { sections.reduce(0) { $0 + $1.categories.count } }
    var totalAudiobookCategories: Int { audiobookSections.reduce(0) { $0 + $1.categories.count } }
    
    private init() {
        loadCatalog()
        loadLibriVoxMatches()
        buildAudiobookSections()
        buildSearchCorpus()
    }
    
    // MARK: - Cover Image URL
    
    /// Derive cover image URL from a Gutenberg ID.
    static func coverURL(gutenbergId: String) -> URL? {
        URL(string: "https://www.gutenberg.org/cache/epub/\(gutenbergId)/pg\(gutenbergId).cover.medium.jpg")
    }
    
    /// EPUB3 download URL for a Gutenberg ID.
    static func epub3URL(gutenbergId: String) -> URL? {
        URL(string: "https://www.gutenberg.org/ebooks/\(gutenbergId).epub3.images")
    }
    
    /// Check if a Gutenberg ID has a LibriVox recording.
    func hasLibriVoxRecording(gutenbergId: String?) -> Bool {
        guard let gid = gutenbergId, let eid = Int(gid) else { return false }
        return librivoxIds.contains(eid)
    }
    
    /// Get LibriVox details for a book.
    func librivoxDetails(gutenbergId: String?) -> LibriVoxMatch? {
        guard let gid = gutenbergId, let eid = Int(gid) else { return nil }
        return librivoxMatches[eid]
    }
    
    /// Books in a specific category.
    func books(inCategory categoryId: Int) -> [GutenbergCatalogBook] {
        for section in sections {
            for category in section.categories {
                if category.bookshelf_id == categoryId {
                    return category.books
                }
            }
        }
        return []
    }
    
    /// Audiobooks in a specific category.
    func audiobooks(inCategory categoryId: Int) -> [GutenbergCatalogBook] {
        books(inCategory: categoryId).filter { librivoxIds.contains($0.ebook_id) }
    }
    
    /// Genre tags for a book (derived from its categories).
    func genres(for ebookId: Int) -> [String] {
        bookCategories[ebookId] ?? []
    }
    
    // MARK: - Build Audiobook Sections
    
    private func buildAudiobookSections() {
        // Build reverse map: ebook_id → [category names]
        for section in sections {
            for category in section.categories {
                for book in category.books {
                    bookCategories[book.ebook_id, default: []].append(category.name)
                }
            }
        }
        
        // Build audiobook-only sections (filter out categories/sections with no audiobooks)
        audiobookSections = sections.compactMap { section in
            let filteredCategories = section.categories.compactMap { category -> GutenbergCatalogCategory? in
                let audiobooks = category.books.filter { librivoxIds.contains($0.ebook_id) }
                guard !audiobooks.isEmpty else { return nil }
                return GutenbergCatalogCategory(
                    name: category.name,
                    bookshelf_id: category.bookshelf_id,
                    books: audiobooks
                )
            }
            guard !filteredCategories.isEmpty else { return nil }
            return GutenbergCatalogSection(section: section.section, categories: filteredCategories)
        }
        
        let audiobookCatCount = audiobookSections.reduce(0) { $0 + $1.categories.count }
        print("[GutenbergCatalog] Built \(audiobookSections.count) audiobook sections, \(audiobookCatCount) categories with audiobooks")
    }
    
    // MARK: - Build Search Corpus
    
    private func buildSearchCorpus() {
        for book in allBooks {
            let cats = bookCategories[book.ebook_id]?.joined(separator: ", ") ?? ""
            searchCorpus[book.ebook_id] = "\(book.title) by \(book.author) | \(cats)"
        }
    }
    
    // MARK: - Private Loaders
    
    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "gutenberg_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[GutenbergCatalog] ⚠️ gutenberg_catalog.json not found in bundle")
            return
        }
        
        do {
            sections = try JSONDecoder().decode([GutenbergCatalogSection].self, from: data)
            
            // Dedup all books
            var seen = Set<Int>()
            var uniqueBooks: [GutenbergCatalogBook] = []
            for section in sections {
                for category in section.categories {
                    for book in category.books {
                        if !seen.contains(book.ebook_id) {
                            seen.insert(book.ebook_id)
                            uniqueBooks.append(book)
                        }
                    }
                }
            }
            allBooks = uniqueBooks
            
            print("[GutenbergCatalog] Loaded \(allBooks.count) unique books across \(totalCategories) categories")
        } catch {
            print("[GutenbergCatalog] ⚠️ Failed to decode catalog: \(error)")
        }
    }
    
    private func loadLibriVoxMatches() {
        guard let url = Bundle.main.url(forResource: "librivox_matches", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[GutenbergCatalog] ⚠️ librivox_matches.json not found in bundle")
            return
        }
        
        do {
            let matchData = try JSONDecoder().decode(LibriVoxMatchData.self, from: data)
            librivoxIds = Set(matchData.matched_ebook_ids)
            for match in matchData.matches {
                librivoxMatches[match.ebook_id] = match
            }
            print("[GutenbergCatalog] Loaded \(librivoxIds.count) LibriVox matches")
        } catch {
            print("[GutenbergCatalog] ⚠️ Failed to decode LibriVox matches: \(error)")
        }
    }
}
