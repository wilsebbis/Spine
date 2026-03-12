import Foundation
import SwiftData

// MARK: - Ingestion Pipeline
// Orchestrates the full EPUB import flow:
// file copy → parse → normalize → segment → persist to SwiftData.

@MainActor
final class IngestionPipeline {
    
    private let modelContext: ModelContext
    private let parser = EPUBParser()
    private let segmenter: SegmentationEngine
    
    enum IngestionError: LocalizedError {
        case bookNotFound
        case parsingFailed(String)
        case segmentationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .bookNotFound: return "Book record not found"
            case .parsingFailed(let reason): return "EPUB parsing failed: \(reason)"
            case .segmentationFailed(let reason): return "Segmentation failed: \(reason)"
            }
        }
    }
    
    init(
        modelContext: ModelContext,
        wordsPerMinute: Int = 225
    ) {
        self.modelContext = modelContext
        self.segmenter = SegmentationEngine(config: .init(
            minWords: 1500,
            maxWords: 3000,
            targetWords: 2250,
            wordsPerMinute: wordsPerMinute
        ))
    }
    
    // MARK: - Public API
    
    /// Import an EPUB file, creating or updating a Book record.
    /// Returns the fully ingested Book with chapters and reading units.
    func ingest(epubURL: URL) async throws -> Book {
        AnalyticsService.shared.log(.bookImportStarted, properties: [
            "filename": epubURL.lastPathComponent
        ])
        
        // 1. Copy EPUB to app's documents directory
        let localURL = try copyToDocuments(epubURL)
        
        // 2. Parse EPUB (synchronous — EPUBParser is a plain class)
        let parsed: ParsedEPUB
        do {
            parsed = try parser.parse(epubURL: localURL)
        } catch {
            AnalyticsService.shared.log(.bookImportFailed, properties: [
                "error": error.localizedDescription
            ])
            throw IngestionError.parsingFailed(error.localizedDescription)
        }
        
        // 3. Extract cover image
        let coverData = try? parser.extractCoverImage(epubURL: localURL)
        
        // 4. Create Book
        let sanitizedDescription = Self.sanitizeDescription(parsed.metadata.description)
        let book = Book(
            title: parsed.metadata.title,
            author: parsed.metadata.author,
            bookDescription: sanitizedDescription,
            coverImageData: coverData,
            sourceType: .gutenberg,
            language: parsed.metadata.language,
            gutenbergId: parsed.metadata.identifier
        )
        book.localFileURI = localURL.path
        book.importStatus = .parsing
        book.rawMetadataJSON = encodeJSON(parsed.metadata.rawMetadata)
        
        modelContext.insert(book)
        
        // 5. Create chapters
        for parsedChapter in parsed.chapters {
            let chapter = Chapter(
                book: book,
                ordinal: parsedChapter.ordinal,
                title: parsedChapter.title,
                sourceHref: parsedChapter.sourceHref,
                plainText: parsedChapter.plainText,
                htmlContent: parsedChapter.htmlContent,
                wordCount: parsedChapter.wordCount
            )
            modelContext.insert(chapter)
        }
        
        // 6. Segment into reading units
        book.importStatus = .segmenting
        let segmentedUnits = segmenter.segment(chapters: parsed.chapters)
        
        for unit in segmentedUnits {
            // Find the parent chapter
            let parentChapter = book.chapters.first { $0.ordinal == unit.chapterOrdinal }
            
            let readingUnit = ReadingUnit(
                book: book,
                chapter: parentChapter,
                ordinal: unit.ordinal,
                title: unit.title,
                plainText: unit.plainText,
                htmlContent: unit.htmlContent,
                wordCount: unit.wordCount,
                estimatedMinutes: unit.estimatedMinutes,
                startCharOffset: unit.startCharOffset,
                endCharOffset: unit.endCharOffset
            )
            modelContext.insert(readingUnit)
        }
        
        // 7. Create initial reading progress
        let progress = ReadingProgress(book: book)
        if let firstUnit = book.sortedUnits.first {
            progress.currentUnitId = firstUnit.id
        }
        modelContext.insert(progress)
        
        // 8. Compute synopsis embedding for recommendations
        let embeddingService = EmbeddingService()
        if !book.bookDescription.isEmpty,
           let vector = embeddingService.embed(text: book.bookDescription) {
            book.synopsisEmbedding = embeddingService.encode(vector)
        }
        
        // 9. Mark complete
        book.importStatus = .completed
        book.updatedAt = Date()
        
        try modelContext.save()
        
        AnalyticsService.shared.log(.bookImportCompleted, properties: [
            "title": book.title,
            "chapters": String(book.chapters.count),
            "units": String(book.readingUnits.count),
            "totalWords": String(book.totalWordCount)
        ])
        
        return book
    }
    
    // MARK: - Helpers
    
    private func copyToDocuments(_ url: URL) throws -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let booksDir = documentsDir.appendingPathComponent("EPUBs", isDirectory: true)
        
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        
        let destURL = booksDir.appendingPathComponent(url.lastPathComponent)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        
        try FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }
    
    private func encodeJSON(_ dict: [String: String]) -> String? {
        guard let data = try? JSONEncoder().encode(dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Description Sanitizer
    
    /// Strips junk EPUB metadata descriptions (Z-Library, calibre, Gutenberg boilerplate).
    /// Returns empty string if the description appears to be metadata rather than content.
    static func sanitizeDescription(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Junk patterns — case insensitive
        let junkPatterns: [String] = [
            "z-library", "z-lib", "zlibrary",
            "downloaded from", "download from",
            "calibre", "converted by",
            "generated by", "produced by",
            "this ebook", "this e-book",
            "project gutenberg", "gutenberg.org",
            "free ebook", "free e-book",
            "public domain",
            "***", "---",
            "transcriber", "digitized",
            "encoding:", "charset",
            "ocr",
        ]
        
        let lowered = trimmed.lowercased()
        for pattern in junkPatterns {
            if lowered.contains(pattern) {
                return ""
            }
        }
        
        // Too short to be a real description
        if trimmed.count < 20 { return "" }
        
        return trimmed
    }
}
