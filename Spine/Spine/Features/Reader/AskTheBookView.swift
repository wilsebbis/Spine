import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Ask the Book View
// Chat-style Q&A interface powered by progress-aware RAG.
// Only references content the user has already read.
// Persists conversation history per book with a Clear option.
// AI-generated follow-up suggestions always visible.

struct AskTheBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let book: Book
    let currentUnitOrdinal: Int
    
    @Query private var allChatMessages: [BookChatMessage]
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var showClearConfirmation = false
    @State private var suggestedQuestions: [String] = []
    @State private var isGeneratingSuggestions = false
    
    private let ragService = BookRAGService()
    
    /// Filter messages for this book
    private var messages: [BookChatMessage] {
        allChatMessages
            .filter { $0.book?.id == book.id }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    init(book: Book, currentUnitOrdinal: Int) {
        self.book = book
        self.currentUnitOrdinal = currentUnitOrdinal
        self._allChatMessages = Query()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Spoiler badge
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "shield.checkered")
                        .font(.caption2)
                    Text("Based on Units 1–\(currentUnitOrdinal + 1) (your progress)")
                        .font(SpineTokens.Typography.caption2)
                }
                .foregroundStyle(SpineTokens.Colors.successGreen)
                .padding(.vertical, SpineTokens.Spacing.xs)
                .padding(.horizontal, SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.successGreen.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, SpineTokens.Spacing.xs)
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: SpineTokens.Spacing.sm) {
                            if messages.isEmpty && !isThinking {
                                // Empty state
                                emptyState
                            }
                            
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                            
                            if isThinking {
                                thinkingBubble
                                    .id("thinking")
                            }
                        }
                        .padding(SpineTokens.Spacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Suggested questions — always visible
                if !suggestedQuestions.isEmpty && !isThinking {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SpineTokens.Spacing.xs) {
                            ForEach(suggestedQuestions, id: \.self) { question in
                                suggestedQuestionButton(question)
                            }
                        }
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                    }
                } else if isGeneratingSuggestions {
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(SpineTokens.Colors.warmStone)
                        Text("Generating questions…")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.warmStone)
                    }
                    .padding(.vertical, SpineTokens.Spacing.xs)
                }
                
                // Input bar
                HStack(spacing: SpineTokens.Spacing.sm) {
                    TextField("Ask about the book…", text: $inputText, axis: .vertical)
                        .font(SpineTokens.Typography.body)
                        .lineLimit(1...3)
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                        .background(SpineTokens.Colors.warmStone.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                inputText.isEmpty ? SpineTokens.Colors.subtleGray : SpineTokens.Colors.accentGold
                            )
                    }
                    .disabled(inputText.isEmpty || isThinking)
                }
                .padding(SpineTokens.Spacing.sm)
            }
            .background(SpineTokens.Colors.cream)
            .navigationTitle("Ask the Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !messages.isEmpty {
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear chat history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all messages in this conversation.")
            }
        }
        .task {
            await generateSuggestions()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            Text("Ask anything about what you've read")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .padding(.top, SpineTokens.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Message Bubble
    
    private func messageBubble(_ message: BookChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            
            Text(message.text)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(message.isUser ? .white : SpineTokens.Colors.espresso)
                .padding(SpineTokens.Spacing.sm)
                .background(
                    message.isUser ?
                    AnyShapeStyle(SpineTokens.Colors.espresso) :
                    AnyShapeStyle(SpineTokens.Colors.warmStone.opacity(0.3))
                )
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            
            if !message.isUser { Spacer(minLength: 60) }
        }
    }
    
    private var thinkingBubble: some View {
        HStack {
            HStack(spacing: SpineTokens.Spacing.xs) {
                ProgressView()
                    .tint(SpineTokens.Colors.accentGold)
                    .scaleEffect(0.8)
                Text("Reading through your progress…")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            .padding(SpineTokens.Spacing.sm)
            .background(SpineTokens.Colors.warmStone.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            
            Spacer(minLength: 60)
        }
    }
    
    private func suggestedQuestionButton(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
                .padding(.horizontal, SpineTokens.Spacing.sm)
                .padding(.vertical, SpineTokens.Spacing.xs)
                .glassEffect(.regular, in: Capsule())
        }
    }
    
    // MARK: - AI Suggestion Generation
    
    private func generateSuggestions() async {
        // Use Foundation Models to generate contextual questions
        guard FoundationModelService.isAvailable else {
            // Fallback to static suggestions
            suggestedQuestions = fallbackSuggestions()
            return
        }
        
        isGeneratingSuggestions = true
        
        do {
            let session = LanguageModelSession()
            
            // Build context about what the reader has seen
            let readUnits = book.sortedUnits.filter { $0.ordinal <= currentUnitOrdinal }
            let recentText = readUnits.suffix(2).map { $0.plainText }.joined(separator: "\n")
            let textSnippet = String(recentText.prefix(1500))
            
            let recentMessages = messages.suffix(4).map { msg in
                "\(msg.isUser ? "User" : "AI"): \(msg.text)"
            }.joined(separator: "\n")
            
            let prompt = """
            You are generating suggested questions for a reader of "\(book.title)" by \(book.author).
            The reader has read through Unit \(currentUnitOrdinal + 1).
            
            Recent passage:
            \(textSnippet)
            
            \(recentMessages.isEmpty ? "" : "Recent chat:\n\(recentMessages)\n")
            
            Generate 4 short, specific questions about the story so far that a reader might want to ask. \
            Make them specific to actual characters, events, or themes from the text — not generic. \
            Each question should be under 50 characters if possible. \
            Reference real character names, places, and events from the passage.
            
            Output ONLY the questions, one per line. No numbering, no quotes, no explanation.
            """
            
            let response = try await session.respond(to: prompt)
            let questions = response.content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count > 5 && $0.count < 80 }
                .prefix(4)
            
            suggestedQuestions = Array(questions)
            
            // If AI didn't return enough, pad with fallbacks
            if suggestedQuestions.count < 3 {
                suggestedQuestions = fallbackSuggestions()
            }
        } catch {
            suggestedQuestions = fallbackSuggestions()
        }
        
        isGeneratingSuggestions = false
    }
    
    private func fallbackSuggestions() -> [String] {
        [
            "Who are the main characters so far?",
            "What's happened in the story?",
            "What themes are emerging?",
            "What should I watch for next?"
        ]
    }
    
    // MARK: - Send
    
    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        
        // Persist user message
        let userMsg = BookChatMessage(book: book, text: question, isUser: true)
        modelContext.insert(userMsg)
        try? modelContext.save()
        
        inputText = ""
        isThinking = true
        
        Task {
            do {
                let answer = try await ragService.ask(
                    question: question,
                    book: book,
                    currentUnitOrdinal: currentUnitOrdinal
                )
                // Persist AI response
                let aiMsg = BookChatMessage(book: book, text: answer, isUser: false)
                modelContext.insert(aiMsg)
                try? modelContext.save()
                
                AnalyticsService.shared.log(.askTheBookUsed, properties: [
                    "bookTitle": book.title
                ])
            } catch {
                let errorMsg = BookChatMessage(
                    book: book,
                    text: "Sorry, I couldn't process that question. Try rephrasing it.",
                    isUser: false
                )
                modelContext.insert(errorMsg)
                try? modelContext.save()
            }
            isThinking = false
            
            // Regenerate suggestions after each Q&A exchange
            await generateSuggestions()
        }
    }
    
    // MARK: - Clear History
    
    private func clearHistory() {
        for msg in messages {
            modelContext.delete(msg)
        }
        try? modelContext.save()
        
        // Regenerate fresh suggestions
        Task { await generateSuggestions() }
    }
}
