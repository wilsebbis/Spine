import Foundation
import SwiftData

// MARK: - Download Service
// Downloads EPUBs from remote URLs (e.g., Project Gutenberg) and feeds them
// through the IngestionPipeline, updating the EXISTING catalog Book.

@MainActor
@Observable
final class DownloadService {
    
    // MARK: - Download State
    
    enum DownloadState: Equatable {
        case idle
        case downloading(progress: Double)
        case ingesting
        case completed
        case failed(String)
    }
    
    /// Track download state per book ID
    var activeDownloads: [UUID: DownloadState] = [:]
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public API
    
    /// Download and ingest an EPUB for a catalog book.
    /// Uses ingestIntoExistingBook so the catalog entry gets chapters/units
    /// and disappears from Available in Discover.
    func download(book: Book) async {
        // Skip if already downloaded
        guard !book.isDownloaded else {
            activeDownloads[book.id] = .completed
            return
        }
        
        // Skip if currently downloading
        if case .downloading = activeDownloads[book.id] { return }
        if case .ingesting = activeDownloads[book.id] { return }
        
        guard let gid = book.gutenbergId, !gid.isEmpty else {
            activeDownloads[book.id] = .failed("No Gutenberg ID")
            return
        }
        
        activeDownloads[book.id] = .downloading(progress: 0)
        
        do {
            // Try multiple URL formats — Gutenberg isn't consistent
            let localURL = try await downloadWithFallback(gutenbergId: gid, bookId: book.id)
            
            // Ingest into the EXISTING catalog book (no duplicate)
            activeDownloads[book.id] = .ingesting
            
            let pipeline = IngestionPipeline(modelContext: modelContext)
            try await pipeline.ingestIntoExistingBook(book, epubURL: localURL)
            
            activeDownloads[book.id] = .completed
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: localURL)
            
            print("✅ Downloaded and ingested: \(book.title)")
            
            // Clear completed state after a moment
            try? await Task.sleep(for: .seconds(2))
            activeDownloads.removeValue(forKey: book.id)
            
        } catch {
            activeDownloads[book.id] = .failed(error.localizedDescription)
            print("⚠️ Download failed for \(book.title): \(error.localizedDescription)")
        }
    }
    
    /// Cancel a download (best-effort).
    func cancel(bookId: UUID) {
        activeDownloads.removeValue(forKey: bookId)
    }
    
    /// Get the current state for a book.
    func state(for bookId: UUID) -> DownloadState {
        activeDownloads[bookId] ?? .idle
    }
    
    // MARK: - Private
    
    /// Try multiple Gutenberg URL formats until one works.
    private func downloadWithFallback(gutenbergId: String, bookId: UUID) async throws -> URL {
        // Gutenberg URL formats in order of preference
        let urls = [
            "https://www.gutenberg.org/ebooks/\(gutenbergId).epub3.images",
            "https://www.gutenberg.org/ebooks/\(gutenbergId).epub.images",
            "https://www.gutenberg.org/ebooks/\(gutenbergId).epub.noimages",
            "https://www.gutenberg.org/cache/epub/\(gutenbergId)/pg\(gutenbergId)-images-3.epub",
            "https://www.gutenberg.org/cache/epub/\(gutenbergId)/pg\(gutenbergId)-images.epub",
            "https://www.gutenberg.org/cache/epub/\(gutenbergId)/pg\(gutenbergId).epub",
        ]
        
        var lastError: Error = DownloadError.serverError
        
        for (index, urlString) in urls.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            
            activeDownloads[bookId] = .downloading(progress: Double(index) / Double(urls.count))
            
            do {
                let localURL = try await downloadFile(from: url, bookId: bookId)
                return localURL
            } catch {
                lastError = error
                // Try next URL format
                continue
            }
        }
        
        throw lastError
    }
    
    private func downloadFile(from url: URL, bookId: UUID) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.serverError
        }
        
        // Verify we got something that looks like an EPUB (not an error HTML page)
        let fileSize = try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int
        guard let size = fileSize, size > 1000 else {
            throw DownloadError.noData
        }
        
        // Move to a stable temp location with .epub extension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(bookId.uuidString)
            .appendingPathExtension("epub")
        
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        
        activeDownloads[bookId] = .downloading(progress: 1.0)
        return dest
    }
    
    enum DownloadError: LocalizedError {
        case serverError
        case noData
        
        var errorDescription: String? {
            switch self {
            case .serverError: return "Server returned an error"
            case .noData: return "No data received"
            }
        }
    }
}
