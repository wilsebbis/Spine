import Foundation
import SwiftData

// MARK: - Reading Club
// SwiftData model for reading clubs — groups of readers
// progressing through a book together at a shared pace.

@Model
final class ReadingClub {
    @Attribute(.unique) var id: UUID
    var name: String
    var clubDescription: String
    var bookId: UUID
    var currentUnit: Int
    var memberCount: Int
    var cloudKitRecordId: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        name: String,
        clubDescription: String = "",
        bookId: UUID,
        currentUnit: Int = 0,
        memberCount: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.clubDescription = clubDescription
        self.bookId = bookId
        self.currentUnit = currentUnit
        self.memberCount = memberCount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
