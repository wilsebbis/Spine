import Foundation
import NaturalLanguage

// MARK: - Embedding Service
// Wraps Apple's NaturalLanguage framework for on-device sentence embeddings.
// Used to compute and compare synopsis similarity for recommendations.

struct EmbeddingService: Sendable {
    
    /// Generate a sentence embedding vector for the given text.
    /// Returns nil if the embedding model is unavailable for the language.
    func embed(text: String, language: NLLanguage = .english) -> [Double]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            print("🧠 NLEmbedding not available for \(language.rawValue)")
            return nil
        }
        
        // NLEmbedding.vector returns a fixed-dimension vector
        guard let vector = embedding.vector(for: text) else {
            return nil
        }
        
        return vector
    }
    
    /// Compute cosine similarity between two embedding vectors.
    /// Returns a value in [-1.0, 1.0] where 1.0 = identical direction.
    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        
        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }
        
        return dotProduct / denominator
    }
    
    /// Encode an embedding vector to Data for SwiftData storage.
    func encode(_ vector: [Double]) -> Data {
        var v = vector
        return Data(bytes: &v, count: v.count * MemoryLayout<Double>.size)
    }
    
    /// Decode an embedding vector from stored Data.
    func decode(_ data: Data) -> [Double] {
        let count = data.count / MemoryLayout<Double>.size
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Double.self).prefix(count))
        }
    }
}
