import Foundation
import SwiftData

// MARK: - Audiobook Chapter
// Represents a single MP3 chapter file from LibriVox.
// Files are kept separate on disk and played sequentially.

@Model
final class AudiobookChapter {
    @Attribute(.unique) var id: UUID
    
    var book: Book?
    var ordinal: Int
    var title: String
    var mp3RemoteURL: String          // Direct MP3 link from LibriVox RSS
    var localFileName: String?         // Filename in Documents/Audiobooks/{bookId}/
    var durationSeconds: Int
    var isListened: Bool
    var isDownloaded: Bool
    
    /// Seconds to skip at the start (e.g., 10s to skip LibriVox disclaimer)
    var startOffset: Double
    
    /// Playback position for resume (seconds)
    var lastPlaybackPosition: Double
    
    /// Alignment data
    @Attribute(.externalStorage) var timingsData: Data?      // Cached ChapterTimings JSON
    @Attribute(.externalStorage) var transcriptText: String?  // Raw ASR transcript
    var alignmentConfidence: Double                           // 0.0–1.0
    var matchedEpubChapterOrdinal: Int                       // Which EPUB chapter this maps to
    
    var createdAt: Date
    
    init(
        book: Book,
        ordinal: Int,
        title: String,
        mp3RemoteURL: String,
        durationSeconds: Int = 0,
        startOffset: Double = 0
    ) {
        self.id = UUID()
        self.book = book
        self.ordinal = ordinal
        self.title = title
        self.mp3RemoteURL = mp3RemoteURL
        self.durationSeconds = durationSeconds
        self.startOffset = startOffset
        self.lastPlaybackPosition = 0
        self.alignmentConfidence = 0
        self.matchedEpubChapterOrdinal = ordinal  // default: same ordinal
        self.isListened = false
        self.isDownloaded = false
        self.createdAt = Date()
    }
    
    /// Full local file URL for playback
    var localFileURL: URL? {
        guard let fileName = localFileName,
              let book else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs
            .appendingPathComponent("Audiobooks", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
    }
    
    /// Decoded alignment timings (word-level sync data)
    var timings: ChapterTimings? {
        get {
            guard let data = timingsData else { return nil }
            return try? JSONDecoder().decode(ChapterTimings.self, from: data)
        }
        set {
            timingsData = try? JSONEncoder().encode(newValue)
        }
    }
}
