import Foundation
import FoundationModels
import os.log

// MARK: - Book RAG Service V2
// Hierarchical, position-aware, spoiler-safe recap engine.
// App-driven retrieval first, tool calling only for bounded follow-ups.
// Mode-specific scoring: quick (recency), storySoFar (summaries), character (entities).

final class BookRAGServiceV2: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.spine.app", category: "ragv2")
    private let embeddingService = EmbeddingService()
    let memoryIndex = BookMemoryIndex()
    
    // MARK: - Build Memory
    
    func buildMemory(book: Book, upToUnit currentOrdinal: Int) async {
        guard !memoryIndex.isBuilt else { return }
        
        memoryIndex.buildIndex(from: book, upToUnit: currentOrdinal)
        
        let readUnits = book.sortedUnits.filter { $0.ordinal <= currentOrdinal }
        
        // Generate unit summaries
        for unit in readUnits {
            guard memoryIndex.unitSummaries[unit.ordinal] == nil else { continue }
            if let summary = await summarize(
                text: unit.plainText, bookTitle: book.title,
                prompt: "Summarize this reading unit in 2 sentences. Key events and character actions only. No markdown."
            ) {
                memoryIndex.addUnitSummary(summary, forUnit: unit.ordinal)
            }
        }
        
        // Generate chapter summaries (could be 1:1 with units, but a cleaner recap)
        for unit in readUnits {
            guard memoryIndex.chapterSummaries[unit.ordinal] == nil else { continue }
            // Use unit summary as input to save tokens
            if let unitSummary = memoryIndex.unitSummaries[unit.ordinal] {
                if let chapterSummary = await summarize(
                    text: unitSummary, bookTitle: book.title,
                    prompt: "Rewrite as a one-sentence chapter recap. No markdown."
                ) {
                    memoryIndex.addChapterSummary(chapterSummary, forUnit: unit.ordinal)
                }
            }
        }
        
        // Generate arc summaries every 3 units
        let arcSize = 3
        var arcStart = 0
        while arcStart + arcSize - 1 <= currentOrdinal {
            let arcEnd = arcStart + arcSize - 1
            guard memoryIndex.arcSummaries[arcStart] == nil else {
                arcStart += arcSize; continue
            }
            let combinedSummaries = (arcStart...arcEnd)
                .compactMap { memoryIndex.chapterSummaries[$0] }
            if !combinedSummaries.isEmpty {
                if let arc = await summarize(
                    text: combinedSummaries.joined(separator: " "),
                    bookTitle: book.title,
                    prompt: "Synthesize into one paragraph capturing the story arc. No markdown."
                ) {
                    memoryIndex.addArcSummary(arc, startUnit: arcStart, endUnit: arcEnd)
                }
            }
            arcStart += arcSize
        }
        
        logger.info("📚 Memory ready: \(self.memoryIndex.entries.count) entries")
    }
    
    // MARK: - Quick Refresher
    
    func quickRefresher(book: Book, currentUnitOrdinal: Int) async throws -> QuickRefresher {
        await buildMemory(book: book, upToUnit: currentUnitOrdinal)
        
        let pack = assembleMemoryPack(
            query: "Recent events",
            currentUnitOrdinal: currentUnitOrdinal,
            mode: .quick,
            maxWords: 600
        )
        
        let session = LanguageModelSession()
        let prompt = """
        From "\(book.title)", give a quick refresher for a reader at Unit \(currentUnitOrdinal + 1).
        
        \(pack)
        """
        
        let response = try await session.respond(to: prompt, generating: QuickRefresher.self)
        return response.content
    }
    
    // MARK: - Story Recap (app-driven, then optional tool follow-up)
    
    func storyRecap(book: Book, currentUnitOrdinal: Int) async throws -> ReadingRecap {
        await buildMemory(book: book, upToUnit: currentUnitOrdinal)
        
        // App-driven first pass: structured memory pack
        let pack = assembleMemoryPack(
            query: "Full story recap",
            currentUnitOrdinal: currentUnitOrdinal,
            mode: .storySoFar,
            maxWords: 800
        )
        
        let instructions = """
        You are a reading companion for "\(book.title)" by \(book.author). \
        The reader is at Unit \(currentUnitOrdinal + 1). \
        Use ONLY the provided context. No spoilers.
        """
        
        // Bounded tools only for follow-up if model needs more
        let tools: [any Tool] = [
            RecentChapterSummariesTool(memoryIndex: memoryIndex),
            SearchRelevantScenesTool(
                memoryIndex: memoryIndex,
                embeddingService: embeddingService,
                currentUnitOrdinal: currentUnitOrdinal
            )
        ]
        
        let session = LanguageModelSession(tools: tools, instructions: instructions)
        let prompt = """
        Generate a complete story recap from this context:
        
        \(pack)
        """
        
        let response = try await session.respond(to: prompt, generating: ReadingRecap.self)
        return response.content
    }
    
    // MARK: - Character Refresher
    
    func characterRefresher(book: Book, currentUnitOrdinal: Int) async throws -> CharacterRefresher {
        await buildMemory(book: book, upToUnit: currentUnitOrdinal)
        
        let pack = assembleMemoryPack(
            query: "Character status update",
            currentUnitOrdinal: currentUnitOrdinal,
            mode: .character(),
            maxWords: 700
        )
        
        // Add character entity data
        let topChars = memoryIndex.entities(ofType: "person")
            .prefix(8)
            .map { "\($0.name): \($0.totalMentions) mentions" }
            .joined(separator: ", ")
        
        let session = LanguageModelSession()
        let prompt = """
        For "\(book.title)" through Unit \(currentUnitOrdinal + 1), \
        describe where each major character stands. Characters: \(topChars)
        
        \(pack)
        """
        
        let response = try await session.respond(to: prompt, generating: CharacterRefresher.self)
        return response.content
    }
    
    // MARK: - Enhanced Ask
    
    func ask(question: String, book: Book, currentUnitOrdinal: Int) async throws -> String {
        await buildMemory(book: book, upToUnit: currentUnitOrdinal)
        
        let pack = assembleMemoryPack(
            query: question,
            currentUnitOrdinal: currentUnitOrdinal,
            mode: .storySoFar,
            maxWords: 700
        )
        
        let tools: [any Tool] = [
            SearchRelevantScenesTool(
                memoryIndex: memoryIndex,
                embeddingService: embeddingService,
                currentUnitOrdinal: currentUnitOrdinal
            ),
            CharacterArcTool(memoryIndex: memoryIndex)
        ]
        
        let session = LanguageModelSession(
            tools: tools,
            instructions: "Reading companion for \"\(book.title)\". Reader at Unit \(currentUnitOrdinal + 1). No spoilers."
        )
        
        let response = try await session.respond(to: "\(question)\n\nContext:\n\(pack)")
        return response.content
    }
    
    // MARK: - Two-Stage Retrieval with Diversity + Adjacent Expansion
    
    private func assembleMemoryPack(
        query: String,
        currentUnitOrdinal: Int,
        mode: RecapMode,
        maxWords: Int
    ) -> String {
        let queryEmbedding = embeddingService.embed(text: query) ?? []
        let queryEntities = memoryIndex.extractQueryEntities(query)
        let weights = weightsForMode(mode)
        
        // Filter to spoiler ceiling
        let candidates = memoryIndex.entries
            .filter { $0.unitOrdinal <= currentUnitOrdinal }
        
        // Stage 1: Score per tier, select top candidates from each
        let tiered = retrievePerTier(
            candidates: candidates,
            queryEmbedding: queryEmbedding,
            queryEntities: queryEntities,
            currentUnitOrdinal: currentUnitOrdinal,
            weights: weights,
            mode: mode
        )
        
        // Stage 2: Global rerank with diversity penalty
        let reranked = rerankWithDiversity(tiered, currentUnitOrdinal: currentUnitOrdinal)
        
        // Stage 3: Adjacent expansion for top scene entries
        let expanded = expandWithNeighbors(reranked, currentUnitOrdinal: currentUnitOrdinal)
        
        // Assemble into compact pack under word budget
        var pack: [String] = []
        var wordCount = 0
        
        for entry in expanded {
            let entryWords = entry.text.split(separator: " ").count
            if wordCount + entryWords > maxWords { continue }
            pack.append("[\(entry.tier.label) — Unit \(entry.unitOrdinal + 1)]\n\(entry.text)")
            wordCount += entryWords
        }
        
        logger.info("📦 Pack: \(pack.count) entries, ~\(wordCount) words")
        return pack.joined(separator: "\n\n---\n\n")
    }
    
    // MARK: - Per-Tier Retrieval
    
    private func retrievePerTier(
        candidates: [BookMemoryIndex.MemoryEntry],
        queryEmbedding: [Double],
        queryEntities: Set<String>,
        currentUnitOrdinal: Int,
        weights: RetrievalWeights,
        mode: RecapMode
    ) -> [BookMemoryIndex.MemoryEntry] {
        // Define budget per tier based on mode
        let budget: [BookMemoryIndex.MemoryEntry.Tier: Int]
        switch mode {
        case .quick:
            budget = [.unitSummary: 3, .chapterSummary: 2, .scene: 1, .arcSummary: 0, .chunk: 0]
        case .storySoFar:
            budget = [.arcSummary: 2, .chapterSummary: 3, .unitSummary: 2, .scene: 3, .chunk: 0]
        case .character:
            budget = [.chapterSummary: 2, .unitSummary: 1, .scene: 4, .arcSummary: 1, .chunk: 2]
        }
        
        var selected: [BookMemoryIndex.MemoryEntry] = []
        
        for (tier, limit) in budget where limit > 0 {
            let tierCandidates = candidates.filter { $0.tier == tier }
            let scored = tierCandidates.map { entry -> (BookMemoryIndex.MemoryEntry, Double) in
                let score = computeScore(
                    entry: entry, queryEmbedding: queryEmbedding,
                    queryEntities: queryEntities,
                    currentUnitOrdinal: currentUnitOrdinal,
                    weights: weights
                )
                return (entry, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            
            selected.append(contentsOf: scored.map { $0.0 })
        }
        
        return selected
    }
    
    // MARK: - Diversity Reranking
    
    private func rerankWithDiversity(
        _ entries: [BookMemoryIndex.MemoryEntry],
        currentUnitOrdinal: Int
    ) -> [BookMemoryIndex.MemoryEntry] {
        guard entries.count > 1 else { return entries }
        
        var result: [BookMemoryIndex.MemoryEntry] = []
        var remaining = entries
        var usedUnitCounts: [Int: Int] = [:]
        
        // Greedy selection with diversity penalty
        while !remaining.isEmpty {
            var bestIdx = 0
            var bestScore = -Double.infinity
            
            for (i, entry) in remaining.enumerated() {
                let unitCount = usedUnitCounts[entry.unitOrdinal, default: 0]
                let diversityPenalty = Double(unitCount) * 0.3
                
                // Prefer higher-tier entries
                let tierBonus = Double(entry.tier.rawValue) * 0.1
                
                // Check similarity to already-selected entries
                var redundancyPenalty = 0.0
                for selected in result {
                    if !entry.embedding.isEmpty && !selected.embedding.isEmpty {
                        let sim = embeddingService.cosineSimilarity(entry.embedding, selected.embedding)
                        if sim > 0.85 { redundancyPenalty += 0.5 }
                    }
                }
                
                let score = tierBonus - diversityPenalty - redundancyPenalty
                if score > bestScore {
                    bestScore = score
                    bestIdx = i
                }
            }
            
            let chosen = remaining.remove(at: bestIdx)
            usedUnitCounts[chosen.unitOrdinal, default: 0] += 1
            result.append(chosen)
        }
        
        return result
    }
    
    // MARK: - Adjacent Expansion
    
    private func expandWithNeighbors(
        _ entries: [BookMemoryIndex.MemoryEntry],
        currentUnitOrdinal: Int
    ) -> [BookMemoryIndex.MemoryEntry] {
        var expanded = entries
        var expandedIDs = Set(entries.map { $0.id })
        
        // Expand top 2 scene/chunk entries with neighbors
        let scenesAndChunks = entries.filter { $0.tier == .scene || $0.tier == .chunk }
        for entry in scenesAndChunks.prefix(2) {
            let neighbors = memoryIndex.neighbors(of: entry.id)
                .filter { $0.unitOrdinal <= currentUnitOrdinal && !expandedIDs.contains($0.id) }
            for neighbor in neighbors {
                expanded.append(neighbor)
                expandedIDs.insert(neighbor.id)
            }
        }
        
        // Sort by unit ordinal for narrative order
        return expanded.sorted { $0.unitOrdinal < $1.unitOrdinal }
    }
    
    // MARK: - Scoring
    
    private func computeScore(
        entry: BookMemoryIndex.MemoryEntry,
        queryEmbedding: [Double],
        queryEntities: Set<String>,
        currentUnitOrdinal: Int,
        weights: RetrievalWeights
    ) -> Double {
        // Semantic similarity
        let similarity: Double
        if !queryEmbedding.isEmpty && !entry.embedding.isEmpty {
            similarity = max(0, embeddingService.cosineSimilarity(queryEmbedding, entry.embedding))
        } else { similarity = 0 }
        
        // Recency (exponential decay)
        let distance = Double(currentUnitOrdinal - entry.unitOrdinal)
        let maxDist = max(1.0, Double(currentUnitOrdinal))
        let recency = exp(-2.0 * distance / maxDist)
        
        // Position proximity
        let proximity: Double
        let gap = abs(entry.unitOrdinal - currentUnitOrdinal)
        if gap <= 2 { proximity = 1.0 }
        else if gap <= 5 { proximity = 0.5 }
        else { proximity = 0.1 }
        
        // Entity overlap
        let entityOverlap: Double
        if !queryEntities.isEmpty && !entry.entityMentions.isEmpty {
            entityOverlap = Double(queryEntities.intersection(entry.entityMentions).count) / Double(queryEntities.count)
        } else { entityOverlap = 0 }
        
        // Summary tier boost
        let tierBoost: Double
        switch entry.tier {
        case .arcSummary: tierBoost = 1.0
        case .chapterSummary: tierBoost = 0.8
        case .unitSummary: tierBoost = 0.6
        case .scene: tierBoost = 0.3
        case .chunk: tierBoost = 0.0
        }
        
        return weights.semantic * similarity
            + weights.recency * recency
            + weights.proximity * proximity
            + weights.entity * entityOverlap
            + weights.summaryTier * tierBoost
    }
    
    // MARK: - Mode Weights
    
    private func weightsForMode(_ mode: RecapMode) -> RetrievalWeights {
        switch mode {
        case .quick: return .quick
        case .storySoFar: return .storySoFar
        case .character: return .character
        }
    }
    
    // MARK: - Summary Generation (separate sessions)
    
    private func summarize(text: String, bookTitle: String, prompt: String) async -> String? {
        guard FoundationModelService.isAvailable else { return nil }
        do {
            let session = LanguageModelSession()
            let words = text.split(separator: " ")
            let truncated = words.prefix(1500).joined(separator: " ")
            let fullPrompt = "From \"\(bookTitle)\":\n\n\(truncated)\n\n\(prompt)"
            let response = try await session.respond(to: fullPrompt)
            return response.content
        } catch {
            logger.warning("⚠️ Summarize failed: \(error.localizedDescription)")
            return nil
        }
    }
}
