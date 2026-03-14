import Foundation
import SwiftData

// MARK: - Reading Path
// A curated journey through a themed set of classics.
// Paths are the primary discovery and commitment mechanism —
// users pick a path before they pick a book.

@Model
final class ReadingPath {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var pathDescription: String
    var iconName: String           // SF Symbol
    var themeColorHex: String      // hex for accent tint
    var difficulty: Difficulty
    var estimatedWeeks: Int
    var sortOrder: Int
    
    // Book IDs (ordered) — matched against Book.id
    var bookIds: [UUID]
    
    // Timestamps
    var createdAt: Date
    
    // MARK: - Difficulty
    
    enum Difficulty: String, Codable, CaseIterable, Sendable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var emoji: String {
            switch self {
            case .beginner: return "🌱"
            case .intermediate: return "📚"
            case .advanced: return "🎓"
            }
        }
        
        var color: String {
            switch self {
            case .beginner: return "4CAF50"
            case .intermediate: return "FF9800"
            case .advanced: return "F44336"
            }
        }
    }
    
    init(
        title: String,
        subtitle: String,
        description: String,
        iconName: String,
        themeColorHex: String,
        difficulty: Difficulty,
        estimatedWeeks: Int,
        sortOrder: Int,
        bookIds: [UUID] = []
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.pathDescription = description
        self.iconName = iconName
        self.themeColorHex = themeColorHex
        self.difficulty = difficulty
        self.estimatedWeeks = estimatedWeeks
        self.sortOrder = sortOrder
        self.bookIds = bookIds
        self.createdAt = Date()
    }
    
    // MARK: - Computed Progress
    
    /// Calculate path progress given a list of all books in the library.
    func progress(books: [Book]) -> Double {
        guard !bookIds.isEmpty else { return 0 }
        let pathBooks = books.filter { bookIds.contains($0.id) }
        guard !pathBooks.isEmpty else { return 0 }
        
        let totalUnits = pathBooks.reduce(0) { $0 + $1.unitCount }
        guard totalUnits > 0 else { return 0 }
        
        let completedUnits = pathBooks.reduce(0) { sum, book in
            sum + (book.readingProgress?.completedUnitCount ?? 0)
        }
        return Double(completedUnits) / Double(totalUnits)
    }
    
    /// Number of books in this path that the user has finished.
    func booksFinished(books: [Book]) -> Int {
        let pathBooks = books.filter { bookIds.contains($0.id) }
        return pathBooks.filter { $0.readingProgress?.isFinished == true }.count
    }
    
    /// Whether the user has started any book in this path.
    func isStarted(books: [Book]) -> Bool {
        let pathBooks = books.filter { bookIds.contains($0.id) }
        return pathBooks.contains { ($0.readingProgress?.completedUnitCount ?? 0) > 0 }
    }
    
    /// The next unfinished book in path order.
    func nextBook(books: [Book]) -> Book? {
        for bookId in bookIds {
            if let book = books.first(where: { $0.id == bookId }),
               book.readingProgress?.isFinished != true {
                return book
            }
        }
        return nil
    }
}
