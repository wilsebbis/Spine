import Foundation
import SwiftData

// MARK: - Timed Word
// Matches the web's timed_text.json schema: { i, t0, t1, w }

struct TimedWord: Codable, Hashable, Identifiable {
    var id: Int { i }
    let i: Int          // word index in chapter
    let t0: Double      // start time (seconds)
    let t1: Double      // end time (seconds)
    let w: String       // word text
}

// MARK: - Timed Phrase (paragraph grouping)

struct TimedPhrase: Codable, Hashable, Identifiable {
    var id: Int { start }
    let start: Int      // first word index
    let end: Int        // last word index
}

// MARK: - Chapter Timings (full chapter sync data)

struct ChapterTimings: Codable {
    let words: [TimedWord]
    let paragraphs: [TimedPhrase]
    
    /// Binary search for the active word at the given playback time.
    /// Mirrors the web's `tick()` function.
    func activeWordIndex(at time: Double) -> Int? {
        var lo = 0
        var hi = words.count - 1
        
        while lo <= hi {
            let mid = (lo + hi) / 2
            let word = words[mid]
            
            if time >= word.t0 && time < word.t1 {
                return mid
            } else if time < word.t0 {
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }
        return nil
    }
    
    /// Find the phrase containing the given word index.
    func phraseContaining(wordIndex: Int) -> TimedPhrase? {
        paragraphs.first { wordIndex >= $0.start && wordIndex <= $0.end }
    }
    
    /// Get all words in a phrase.
    func words(in phrase: TimedPhrase) -> [TimedWord] {
        words.filter { $0.i >= phrase.start && $0.i <= phrase.end }
    }
}

// MARK: - Book Audio File (SwiftData persistence)

enum AudioSyncStatus: String, Codable {
    case pending
    case processing
    case synced
    case failed
}

@Model
final class BookAudioFile {
    var bookID: UUID
    var audioFileName: String
    var syncStatusRaw: String
    var timingsData: Data?
    var importedAt: Date
    var processingProgress: Double  // 0.0–1.0
    var errorMessage: String?
    
    var syncStatus: AudioSyncStatus {
        get { AudioSyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var timings: ChapterTimings? {
        get {
            guard let data = timingsData else { return nil }
            return try? JSONDecoder().decode(ChapterTimings.self, from: data)
        }
        set {
            timingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(bookID: UUID, audioFileName: String) {
        self.bookID = bookID
        self.audioFileName = audioFileName
        self.syncStatusRaw = AudioSyncStatus.pending.rawValue
        self.importedAt = Date()
        self.processingProgress = 0.0
    }
}
