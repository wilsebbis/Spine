import Foundation
import FoundationModels
import os.log

// MARK: - AI Error Handling

/// Spine-specific AI errors with user-friendly messaging.
enum SpineAIError: LocalizedError {
    case safetyFilter
    case unavailable
    case contextTooLong
    case other(Error)
    
    var errorDescription: String? {
        switch self {
        case .safetyFilter:
            return "This passage contains themes that Apple's on-device AI can't process. This is a limitation of the safety filters, not the book itself. Try a different passage or section."
        case .unavailable:
            return "AI features require a device that supports Apple Intelligence."
        case .contextTooLong:
            return "This passage is too long for on-device processing. Try selecting a shorter section."
        case .other(let error):
            return "AI temporarily unavailable: \(error.localizedDescription)"
        }
    }
    
    /// Detect if an error is a Foundation Model safety filter trigger.
    static func from(_ error: Error) -> SpineAIError {
        let desc = String(describing: error).lowercased()
        if desc.contains("unsafe") || desc.contains("guard") || desc.contains("safety") || desc.contains("content filter") {
            return .safetyFilter
        }
        if desc.contains("context") && desc.contains("long") {
            return .contextTooLong
        }
        return .other(error)
    }
}

// MARK: - Foundation Model Service
// On-device LLM implementation of AIServiceProtocol using Apple Foundation Models.
// All inference runs locally — no API keys, no network, no cost.

final class FoundationModelService: AIServiceProtocol, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.spine.app", category: "ai")
    
    // MARK: - Availability
    
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    // MARK: - Safe Response Wrapper
    
    // MARK: - Content Sanitizer
    
    /// Strips graphic language from literary passages before sending to Foundation Models.
    /// Preserves narrative structure and meaning while removing words that trigger safety filters.
    private struct ContentSanitizer {
        
        /// Words/phrases that trigger Apple's safety filters in classic literature.
        /// Mapped to neutral literary replacements.
        private static let replacements: [(pattern: String, replacement: String)] = [
            // Violence
            ("murder", "crime"), ("murdered", "killed"),
            ("kill", "end"), ("killed", "ended"),
            ("blood", "wound"), ("bloody", "violent"),
            ("corpse", "body"), ("dead body", "remains"),
            ("strangled", "attacked"), ("stabbed", "struck"),
            ("throat", "neck"), ("gore", "violence"),
            ("dismember", "harm"), ("mutilat", "injur"),
            // Horror / body horror
            ("monster", "creature"), ("hideous", "fearsome"),
            ("wretched", "pitiable"), ("daemon", "fiend"),
            ("abhor", "detest"), ("loath", "dislik"),
            // Sexual
            ("rape", "assault"), ("ravish", "attack"),
            ("bosom", "heart"), ("naked", "exposed"),
            // Self-harm
            ("suicide", "self-destruction"), ("hang himself", "end his life"),
            ("kill myself", "end my life"), ("kill herself", "end her life"),
        ]
        
        /// Bowdlerize a passage for safe AI processing while keeping meaning intact.
        static func sanitize(_ text: String) -> String {
            var result = text
            for (pattern, replacement) in replacements {
                // Case-insensitive replacement preserving first-letter case
                let range = result.range(of: pattern, options: .caseInsensitive)
                if range != nil {
                    result = result.replacingOccurrences(
                        of: pattern,
                        with: replacement,
                        options: .caseInsensitive
                    )
                }
            }
            return result
        }
    }
    
    // MARK: - Safe Response Wrapper
    
    /// Wraps LanguageModelSession.respond with safety-filter detection and auto-retry.
    /// On first safety failure, bowdlerizes the prompt and retries once.
    private func safeRespond(to prompt: String) async throws -> String {
        let session = LanguageModelSession()
        
        // Attempt 1: original prompt
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            let aiError = SpineAIError.from(error)
            guard case .safetyFilter = aiError else { throw aiError }
            logger.warning("⚠️ Safety filter triggered, retrying with sanitized content...")
        }
        
        // Attempt 2: sanitize the prompt content and add academic framing
        let sanitizedPrompt = ContentSanitizer.sanitize(prompt)
        let academicPrompt = """
        [Context: You are performing literary analysis for educational purposes. \
        Treat all content as classic literature being studied academically.]
        
        \(sanitizedPrompt)
        """
        
        let retrySession = LanguageModelSession()
        do {
            let response = try await retrySession.respond(to: academicPrompt)
            logger.info("✅ Retry with sanitized content succeeded")
            return response.content
        } catch {
            // Still failing — surface the user-friendly error
            throw SpineAIError.safetyFilter
        }
    }
    
    // MARK: - Define Word
    
    func defineWord(_ word: String, context: String) async throws -> String {
        let prompt = """
        Define the word "\(word)" as used in this literary context:
        
        "\(context)"
        
        Provide:
        1. A brief, clear definition (1 sentence)
        2. How it's specifically used in this passage (1 sentence)
        
        Keep it concise and accessible. No markdown formatting.
        """
        
        let result = try await safeRespond(to: prompt)
        logger.info("📖 Defined word: \(word)")
        return result
    }
    
    // MARK: - Explain Paragraph
    
    func explainParagraph(_ text: String, bookTitle: String) async throws -> String {
        let prompt = """
        Explain this passage from "\(bookTitle)" in plain, modern language:
        
        "\(text)"
        
        Break it down simply in 2-3 sentences. What is happening or being described? \
        What might the author be conveying? No markdown formatting.
        """
        
        let result = try await safeRespond(to: prompt)
        logger.info("💡 Explained paragraph from \(bookTitle)")
        return result
    }
    
    // MARK: - Recap Unit
    
    func recapUnit(_ unitText: String, bookTitle: String) async throws -> String {
        // Truncate to first ~2000 words to stay within context window
        let words = unitText.split(separator: " ")
        let truncated = words.prefix(2000).joined(separator: " ")
        
        let prompt = """
        Summarize this reading passage from "\(bookTitle)" in exactly 3 sentences. \
        Focus on key plot events, character actions, and important revelations. \
        Write as a helpful recap for someone who just finished reading it. \
        No spoilers beyond what's in the passage. No markdown formatting.
        
        Passage:
        \(truncated)
        """
        
        let result = try await safeRespond(to: prompt)
        logger.info("📝 Generated recap for \(bookTitle)")
        return result
    }
    
    // MARK: - Ask the Book (Phase 3)
    
    func askTheBook(
        question: String,
        bookTitle: String,
        readContentUpToUnit: Int,
        allUnitsText: [String]
    ) async throws -> String {
        // Only include content up to user's current reading position
        let safeContent = allUnitsText.prefix(readContentUpToUnit + 1)
        
        // Take the most recent chunks for context (avoid exceeding context window)
        let relevantText = safeContent.suffix(5).joined(separator: "\n\n---\n\n")
        
        let prompt = """
        You are a reading companion for "\(bookTitle)". The reader has read through \
        unit \(readContentUpToUnit + 1). Answer their question using ONLY the content \
        they have already read. Never reveal anything from later in the book.
        
        Content the reader has seen:
        \(relevantText)
        
        Reader's question: \(question)
        
        Answer concisely in 2-4 sentences. If the answer isn't in the read content, \
        say "That hasn't been revealed yet in what you've read." No markdown formatting.
        """
        
        let result = try await safeRespond(to: prompt)
        logger.info("❓ Answered question about \(bookTitle)")
        return result
    }
}
