import Foundation
import SwiftData

// MARK: - Audiobook Download Service
// Downloads individual MP3 chapter files from LibriVox RSS feeds.
// Files are kept separate per chapter for sequential playback.
// Tracks download state PER BOOK so multiple cards don't interfere.

@MainActor
@Observable
final class AudiobookDownloadService {
    
    // MARK: - State
    
    enum DownloadState: Equatable {
        case idle
        case fetching          // Querying LibriVox API
        case downloading(chapter: Int, total: Int)
        case completed
        case notAvailable      // Not found on LibriVox
        case failed(String)
    }
    
    /// Per-book download states keyed by Book.id
    var bookStates: [UUID: DownloadState] = [:]
    
    /// Per-book download progress (0...1)
    var bookProgress: [UUID: Double] = [:]
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public API
    
    /// Get the current download state for a specific book.
    func state(for bookId: UUID) -> DownloadState {
        bookStates[bookId] ?? .idle
    }
    
    /// Get overall download progress for a specific book (0...1).
    func progress(for bookId: UUID) -> Double {
        bookProgress[bookId] ?? 0
    }
    
    /// Search LibriVox and download all chapter MP3s for a book.
    func downloadAudiobook(for book: Book) async {
        let bookId = book.id
        
        guard !book.hasAudiobook else {
            bookStates[bookId] = .completed
            return
        }
        
        bookStates[bookId] = .fetching
        bookProgress[bookId] = 0
        
        do {
            // 1. Find audiobook on LibriVox
            guard let match = await LibriVoxService.findBestMatch(title: book.title) else {
                bookStates[bookId] = .notAvailable
                return
            }
            
            // 2. Get chapter MP3 URLs from RSS
            let chapters = try await LibriVoxService.fetchChapters(rssURL: match.urlRss)
            guard !chapters.isEmpty else {
                bookStates[bookId] = .notAvailable
                return
            }
            
            // 3. Create directory for this book's audio files
            let audioDir = try audiobookDirectory(for: book)
            
            // 4. Create AudiobookChapter records
            for (index, chapter) in chapters.enumerated() {
                let audioChapter = AudiobookChapter(
                    book: book,
                    ordinal: index + 1,
                    title: chapter.title,
                    mp3RemoteURL: chapter.mp3URL,
                    durationSeconds: chapter.durationSeconds
                )
                modelContext.insert(audioChapter)
            }
            
            // 5. Save metadata before downloading files
            book.librivoxId = match.id
            book.audiobookDurationSeconds = match.totaltimesecs
            try modelContext.save()
            
            // 6. Download each chapter MP3
            let totalChapters = chapters.count
            
            for (index, chapter) in chapters.enumerated() {
                bookStates[bookId] = .downloading(chapter: index + 1, total: totalChapters)
                bookProgress[bookId] = Double(index) / Double(totalChapters)
                
                guard let mp3URL = URL(string: chapter.mp3URL) else { continue }
                
                let fileName = String(format: "%03d_%@.mp3",
                                      index + 1,
                                      sanitizeFileName(chapter.title))
                let destURL = audioDir.appendingPathComponent(fileName)
                
                // Skip if already downloaded
                if FileManager.default.fileExists(atPath: destURL.path) {
                    updateChapterLocalFile(book: book, ordinal: index + 1, fileName: fileName)
                    continue
                }
                
                // Download with retry
                var downloaded = false
                for attempt in 1...3 {
                    do {
                        let (tempURL, response) = try await URLSession.shared.download(from: mp3URL)
                        
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            continue
                        }
                        
                        try FileManager.default.moveItem(at: tempURL, to: destURL)
                        downloaded = true
                        break
                    } catch {
                        if attempt < 3 {
                            try? await Task.sleep(for: .seconds(1))
                        }
                    }
                }
                
                if downloaded {
                    updateChapterLocalFile(book: book, ordinal: index + 1, fileName: fileName)
                } else {
                    print("⚠️ Failed to download chapter \(index + 1): \(chapter.title)")
                }
            }
            
            // 7. Mark complete
            book.hasAudiobook = true
            book.updatedAt = Date()
            try modelContext.save()
            
            bookProgress[bookId] = 1.0
            bookStates[bookId] = .completed
            
            print("🎧 Audiobook downloaded: \(book.title) (\(totalChapters) chapters)")
            
        } catch {
            bookStates[bookId] = .failed(error.localizedDescription)
            print("⚠️ Audiobook download failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func audiobookDirectory(for book: Book) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs
            .appendingPathComponent("Audiobooks", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func updateChapterLocalFile(book: Book, ordinal: Int, fileName: String) {
        if let chapter = book.audiobookChapters.first(where: { $0.ordinal == ordinal }) {
            chapter.localFileName = fileName
            chapter.isDownloaded = true
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        return name
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { Character($0) }
            .prefix(50)
            .map { String($0) }
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
    }
}
