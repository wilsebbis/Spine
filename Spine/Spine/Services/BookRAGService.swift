import Foundation
import NaturalLanguage
import os.log

// MARK: - Book RAG Service
// Progress-aware retrieval-augmented generation.
// Only ever uses content the user has already read — never spoils ahead.

struct BookRAGService: Sendable {
    
    private let embeddingService = EmbeddingService()
    private let aiService: AIServiceProtocol = FoundationModelService()
    private let logger = Logger(subsystem: "com.spine.app", category: "rag")
    
    // MARK: - Chunk
    
    struct TextChunk: Sendable {
        let unitOrdinal: Int
        let text: String
        let embedding: [Double]
    }
    
    // MARK: - Build Context
    
    /// Build chunks from all units the user has read.
    func buildContext(
        book: Book,
        upToUnit currentOrdinal: Int,
        chunkSize: Int = 500
    ) -> [TextChunk] {
        let readUnits = book.sortedUnits.filter { $0.ordinal <= currentOrdinal }
        var chunks: [TextChunk] = []
        
        for unit in readUnits {
            let words = unit.plainText.split(separator: " ")
            var i = 0
            while i < words.count {
                let end = min(i + chunkSize, words.count)
                let chunkText = words[i..<end].joined(separator: " ")
                let embedding = embeddingService.embed(text: chunkText) ?? []
                
                chunks.append(TextChunk(
                    unitOrdinal: unit.ordinal,
                    text: chunkText,
                    embedding: embedding
                ))
                
                // Overlap by 50 words for context continuity
                i += chunkSize - 50
            }
        }
        
        logger.info("📚 Built \(chunks.count) chunks from \(readUnits.count) units")
        return chunks
    }
    
    // MARK: - Retrieve
    
    /// Find the top-K most relevant chunks for a query.
    func retrieve(query: String, from chunks: [TextChunk], topK: Int = 3) -> [TextChunk] {
        let queryEmbedding = embeddingService.embed(text: query) ?? []
        guard !queryEmbedding.isEmpty else { return Array(chunks.suffix(topK)) }
        
        let scored = chunks.map { chunk in
            (chunk, embeddingService.cosineSimilarity(queryEmbedding, chunk.embedding))
        }
        
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }
    }
    
    // MARK: - Ask
    
    /// Full RAG pipeline: retrieve relevant chunks, then generate an answer.
    func ask(
        question: String,
        book: Book,
        currentUnitOrdinal: Int
    ) async throws -> String {
        let chunks = buildContext(book: book, upToUnit: currentUnitOrdinal)
        let relevant = retrieve(query: question, from: chunks)
        
        let contextTexts = relevant.map { $0.text }
        
        let answer = try await aiService.askTheBook(
            question: question,
            bookTitle: book.title,
            readContentUpToUnit: currentUnitOrdinal,
            allUnitsText: contextTexts
        )
        
        logger.info("❓ RAG answer generated for: \(question.prefix(50))")
        return answer
    }
}
