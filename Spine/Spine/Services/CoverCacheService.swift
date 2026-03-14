import Foundation
import SwiftData
import UIKit

// MARK: - Cover Cache Service
// Pre-fetches cover thumbnails from Gutenberg on first launch.
// Saves directly to Book.coverImageData so covers display instantly
// without any network requests on subsequent launches.

@MainActor
final class CoverCacheService {
    
    private let modelContext: ModelContext
    private var isRunning = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Fetch covers for all books that have a gutenbergId but no coverImageData.
    /// Runs in the background with throttled concurrency to avoid hammering the server.
    func prefetchCovers() {
        guard !isRunning else { return }
        isRunning = true
        
        Task {
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.gutenbergId != nil && book.coverImageData == nil
                }
            )
            
            guard let books = try? modelContext.fetch(descriptor), !books.isEmpty else {
                isRunning = false
                return
            }
            
            print("🖼️ Pre-fetching covers for \(books.count) books...")
            
            var fetched = 0
            var failed = 0
            
            // Process in batches of 8 concurrent downloads
            let batchSize = 8
            for batchStart in stride(from: 0, to: books.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, books.count)
                let batch = Array(books[batchStart..<batchEnd])
                
                await withTaskGroup(of: (Int, Data?).self) { group in
                    for (index, book) in batch.enumerated() {
                        guard let gid = book.gutenbergId else { continue }
                        let url = URL(string: "https://www.gutenberg.org/cache/epub/\(gid)/pg\(gid).cover.medium.jpg")!
                        
                        group.addTask {
                            do {
                                let (data, response) = try await URLSession.shared.data(from: url)
                                guard let http = response as? HTTPURLResponse,
                                      (200...299).contains(http.statusCode),
                                      data.count > 100 else { // Skip tiny error pages
                                    return (index, nil)
                                }
                                
                                // Compress to JPEG at 70% quality to save space
                                if let image = UIImage(data: data),
                                   let compressed = image.jpegData(compressionQuality: 0.7) {
                                    return (index, compressed)
                                }
                                return (index, data)
                            } catch {
                                return (index, nil)
                            }
                        }
                    }
                    
                    for await (index, data) in group {
                        if let data = data {
                            batch[index].coverImageData = data
                            fetched += 1
                        } else {
                            failed += 1
                        }
                    }
                }
                
                // Save every batch
                try? modelContext.save()
                
                // Brief pause between batches to be polite to Gutenberg
                try? await Task.sleep(for: .milliseconds(200))
            }
            
            print("🖼️ Cover pre-fetch complete: \(fetched) fetched, \(failed) unavailable")
            isRunning = false
        }
    }
}
