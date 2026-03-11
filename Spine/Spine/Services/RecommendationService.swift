import Foundation
import SwiftData

// MARK: - Scored Book

/// A book with a computed recommendation score and rationale.
struct ScoredBook: Identifiable, Sendable {
    let id: UUID
    let book: Book
    let score: Double
    let rationale: String   // "Because you liked dark, atmospheric fiction"
    
    init(book: Book, score: Double, rationale: String) {
        self.id = book.id
        self.book = book
        self.score = score
        self.rationale = rationale
    }
}

// MARK: - Recommendation Service
// Hybrid scoring engine that combines multiple signals to rank books.
// Phase 2 MVP uses heuristic weights — architecture supports CoreML model swap later.

struct RecommendationService: Sendable {
    
    private let embeddingService = EmbeddingService()
    
    // MARK: - Scoring Weights
    
    private struct Weights {
        static let genreMatch: Double = 0.30
        static let vibeMatch: Double = 0.25
        static let synopsisSimilarity: Double = 0.20
        static let coLiked: Double = 0.15
        static let novelty: Double = 0.10
        static let avoidedPenalty: Double = 0.40
    }
    
    // MARK: - Public API
    
    /// Generate top-N recommendations for a user from their catalog.
    /// Excludes books the user has already completed or dismissed.
    @MainActor
    func getRecommendations(
        tasteProfile: UserTasteProfile,
        allBooks: [Book],
        interactions: [BookInteraction],
        limit: Int = 10
    ) -> [ScoredBook] {
        // Build exclusion set: completed + dismissed
        let excludedIDs = Set(
            interactions
                .filter { $0.interactionType == .finished || $0.interactionType == .dismissed }
                .compactMap { $0.book?.id }
        )
        
        // Candidate books: not excluded, has chapters (is ingested)
        let candidates = allBooks.filter { book in
            !excludedIDs.contains(book.id) && !book.chapters.isEmpty
        }
        
        guard !candidates.isEmpty else { return [] }
        
        // Build liked book embeddings for synopsis similarity
        let likedBooks = interactions
            .filter { $0.interactionType == .finished && ($0.rating ?? 0) >= 3 }
            .compactMap { $0.book }
        
        // Score each candidate
        var scored = candidates.map { book in
            let (score, rationale) = computeScore(
                book: book,
                profile: tasteProfile,
                likedBooks: likedBooks,
                allCandidates: candidates
            )
            return ScoredBook(book: book, score: score, rationale: rationale)
        }
        
        // Sort descending by score
        scored.sort { $0.score > $1.score }
        
        return Array(scored.prefix(limit))
    }
    
    // MARK: - Scoring Engine
    
    private func computeScore(
        book: Book,
        profile: UserTasteProfile,
        likedBooks: [Book],
        allCandidates: [Book]
    ) -> (Double, String) {
        var score: Double = 0
        var reasons: [String] = []
        
        // 1. Genre Match (Jaccard-like weighted overlap)
        let genreScore = computeGenreMatch(
            bookGenres: book.genres,
            userGenres: profile.preferredGenres
        )
        score += Weights.genreMatch * genreScore
        if genreScore > 0.5 {
            let matchedGenres = book.genres.filter { genre in
                profile.preferredGenres.contains { $0.name.lowercased() == genre.lowercased() }
            }
            if let top = matchedGenres.first {
                reasons.append("you enjoy \(top.lowercased())")
            }
        }
        
        // 2. Vibe Match
        let vibeScore = computeVibeMatch(
            bookVibes: book.vibes,
            likedVibes: profile.preferredVibes,
            avoidedVibes: profile.avoidedVibes
        )
        score += Weights.vibeMatch * vibeScore.match
        score -= Weights.avoidedPenalty * vibeScore.penalty
        if vibeScore.match > 0.5 {
            let matchedVibes = book.vibes.filter { vibe in
                profile.preferredVibes.contains { $0.name.lowercased() == vibe.lowercased() }
            }
            if let top = matchedVibes.first {
                reasons.append("\(top.lowercased()) fiction")
            }
        }
        
        // 3. Synopsis Similarity
        let synopsisScore = computeSynopsisSimilarity(
            book: book,
            likedBooks: likedBooks
        )
        score += Weights.synopsisSimilarity * synopsisScore
        
        // 4. Co-Liked (placeholder — will use MLRecommender later)
        let coLikedScore = computeCoLikedScore(book: book, likedBooks: likedBooks)
        score += Weights.coLiked * coLikedScore
        
        // 5. Novelty Bonus
        let noveltyScore = computeNoveltyBonus(book: book, allCandidates: allCandidates)
        score += Weights.novelty * noveltyScore
        
        // Build rationale string
        let rationale: String
        if reasons.isEmpty {
            rationale = "A classic worth exploring"
        } else {
            rationale = "Because you liked \(reasons.joined(separator: " and "))"
        }
        
        return (max(0, score), rationale)
    }
    
    // MARK: - Individual Scoring Functions
    
    /// Weighted Jaccard-like overlap between book genres and user preferred genres.
    private func computeGenreMatch(bookGenres: [String], userGenres: [TasteWeight]) -> Double {
        guard !bookGenres.isEmpty, !userGenres.isEmpty else { return 0 }
        
        var totalWeight: Double = 0
        var matchWeight: Double = 0
        
        for pref in userGenres {
            totalWeight += pref.weight
            if bookGenres.contains(where: { $0.lowercased() == pref.name.lowercased() }) {
                matchWeight += pref.weight
            }
        }
        
        return totalWeight > 0 ? matchWeight / totalWeight : 0
    }
    
    /// Vibe match with penalty for avoided vibes.
    private func computeVibeMatch(
        bookVibes: [String],
        likedVibes: [TasteWeight],
        avoidedVibes: [String]
    ) -> (match: Double, penalty: Double) {
        guard !bookVibes.isEmpty else { return (0, 0) }
        
        var matchScore: Double = 0
        var totalWeight: Double = 0
        
        for pref in likedVibes {
            totalWeight += pref.weight
            if bookVibes.contains(where: { $0.lowercased() == pref.name.lowercased() }) {
                matchScore += pref.weight
            }
        }
        
        let match = totalWeight > 0 ? matchScore / totalWeight : 0
        
        // Penalty for avoided vibes
        let avoidedCount = bookVibes.filter { vibe in
            avoidedVibes.contains(where: { $0.lowercased() == vibe.lowercased() })
        }.count
        let penalty = Double(avoidedCount) / Double(max(bookVibes.count, 1))
        
        return (match, penalty)
    }
    
    /// Average cosine similarity between this book's synopsis embedding and liked books.
    private func computeSynopsisSimilarity(book: Book, likedBooks: [Book]) -> Double {
        guard let bookData = book.synopsisEmbedding else { return 0 }
        
        let bookVector = embeddingService.decode(bookData)
        guard !bookVector.isEmpty else { return 0 }
        
        let likedVectors = likedBooks.compactMap { liked -> [Double]? in
            guard let data = liked.synopsisEmbedding else { return nil }
            return embeddingService.decode(data)
        }
        
        guard !likedVectors.isEmpty else { return 0 }
        
        let totalSim = likedVectors.reduce(0.0) { sum, vec in
            sum + embeddingService.cosineSimilarity(bookVector, vec)
        }
        
        // Normalize to 0–1 range (cosine can be negative)
        let avgSim = totalSim / Double(likedVectors.count)
        return max(0, (avgSim + 1) / 2)
    }
    
    /// Placeholder co-liked score based on shared genres/vibes with liked books.
    /// Will be replaced by MLRecommender collaborative filtering in Phase 3.
    private func computeCoLikedScore(book: Book, likedBooks: [Book]) -> Double {
        guard !likedBooks.isEmpty else { return 0 }
        
        var overlap: Double = 0
        
        for liked in likedBooks {
            let sharedGenres = Set(book.genres.map { $0.lowercased() })
                .intersection(Set(liked.genres.map { $0.lowercased() }))
            let sharedVibes = Set(book.vibes.map { $0.lowercased() })
                .intersection(Set(liked.vibes.map { $0.lowercased() }))
            
            let totalFeatures = max(Set(book.genres + book.vibes).count, 1)
            overlap += Double(sharedGenres.count + sharedVibes.count) / Double(totalFeatures)
        }
        
        return min(1.0, overlap / Double(likedBooks.count))
    }
    
    /// Bonus for genre diversity — penalizes if top-N is all one genre.
    private func computeNoveltyBonus(book: Book, allCandidates: [Book]) -> Double {
        guard !book.genres.isEmpty, !allCandidates.isEmpty else { return 0.5 }
        
        // Count how many candidates share this book's primary genre
        let primaryGenre = book.genres.first!.lowercased()
        let sameGenreCount = allCandidates.filter { candidate in
            candidate.genres.contains(where: { $0.lowercased() == primaryGenre })
        }.count
        
        // Less common genres get a novelty boost
        let frequency = Double(sameGenreCount) / Double(allCandidates.count)
        return 1.0 - frequency
    }
}
