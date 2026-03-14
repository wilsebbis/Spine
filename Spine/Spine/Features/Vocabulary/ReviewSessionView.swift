import SwiftUI
import SwiftData

// MARK: - Review Session View
// Flashcard-style spaced repetition review.
// This is the secondary loop that helps users retain vocabulary
// from their reading — something a paperback absolutely cannot do.

struct ReviewSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabularyWord.nextReviewDate) private var allWords: [VocabularyWord]
    
    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var sessionComplete = false
    @State private var reviewed = 0
    @State private var correct = 0
    
    private var dueWords: [VocabularyWord] {
        allWords.filter { $0.isDueForReview }
    }
    
    // Limit session to 10 cards max
    private var sessionWords: [VocabularyWord] {
        Array(dueWords.prefix(10))
    }
    
    private var currentWord: VocabularyWord? {
        guard currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    var body: some View {
        NavigationStack {
            if sessionComplete || sessionWords.isEmpty {
                completionScreen
            } else if let word = currentWord {
                flashcardView(word: word)
            }
        }
    }
    
    // MARK: - Flashcard
    
    private func flashcardView(word: VocabularyWord) -> some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            // Progress
            HStack {
                Text("\(currentIndex + 1) of \(sessionWords.count)")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                
                Spacer()
                
                Button("End Session") { sessionComplete = true }
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SpineTokens.Colors.warmStone.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SpineTokens.Colors.accentGold)
                        .frame(width: geo.size.width * Double(currentIndex) / Double(sessionWords.count))
                }
            }
            .frame(height: 4)
            
            Spacer()
            
            // Card
            VStack(spacing: SpineTokens.Spacing.lg) {
                // Word
                Text(word.word)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                // Context
                if !word.contextSentence.isEmpty {
                    Text("\"...\(word.contextSentence)...\"")
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpineTokens.Spacing.md)
                }
                
                if let book = word.book {
                    Text("— \(book.title)")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                // Reveal area
                if isRevealed {
                    VStack(spacing: SpineTokens.Spacing.sm) {
                        Divider()
                        
                        Text(word.definition)
                            .font(SpineTokens.Typography.body)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SpineTokens.Spacing.md)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isRevealed = true
                        }
                    } label: {
                        Text("Tap to reveal definition")
                            .font(SpineTokens.Typography.callout)
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                            .padding(.vertical, SpineTokens.Spacing.sm)
                            .padding(.horizontal, SpineTokens.Spacing.lg)
                            .background(SpineTokens.Colors.softGold)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(SpineTokens.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(SpineTokens.Colors.cream)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            
            Spacer()
            
            // Rating buttons (only after reveal)
            if isRevealed {
                ratingButtons(word: word)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
    }
    
    // MARK: - Rating Buttons
    
    private func ratingButtons(word: VocabularyWord) -> some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            ratingButton(label: "Forgot", emoji: "😵", quality: 0, color: .red)
            ratingButton(label: "Hard", emoji: "😐", quality: 1, color: .orange)
            ratingButton(label: "Good", emoji: "🙂", quality: 2, color: .green)
            ratingButton(label: "Easy", emoji: "😎", quality: 3, color: .blue)
        }
    }
    
    private func ratingButton(label: String, emoji: String, quality: Int, color: Color) -> some View {
        Button {
            recordAndAdvance(quality: quality)
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SpineTokens.Colors.espresso)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpineTokens.Spacing.sm)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        }
    }
    
    private func recordAndAdvance(quality: Int) {
        guard let word = currentWord else { return }
        word.recordReview(quality: quality)
        reviewed += 1
        if quality >= 2 { correct += 1 }
        
        try? modelContext.save()
        
        withAnimation {
            isRevealed = false
            if currentIndex + 1 < sessionWords.count {
                currentIndex += 1
            } else {
                sessionComplete = true
            }
        }
    }
    
    // MARK: - Completion
    
    private var completionScreen: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(SpineTokens.Colors.successGreen)
            
            Text("Review Complete!")
                .font(SpineTokens.Typography.largeTitle)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            if reviewed > 0 {
                VStack(spacing: SpineTokens.Spacing.sm) {
                    statRow(label: "Words reviewed", value: "\(reviewed)")
                    statRow(label: "Remembered", value: "\(correct) / \(reviewed)")
                    statRow(label: "Accuracy", value: "\(reviewed > 0 ? Int(Double(correct) / Double(reviewed) * 100) : 0)%")
                }
                .padding(SpineTokens.Spacing.md)
                .background(SpineTokens.Colors.warmStone.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
            } else {
                Text("No words are due for review right now.\nKeep reading to build your deck!")
                    .font(SpineTokens.Typography.callout)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button { dismiss() } label: {
                Text("Done")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.md)
                    .background(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
        }
        .padding(SpineTokens.Spacing.lg)
        .background(SpineTokens.Colors.cream.ignoresSafeArea())
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
            Spacer()
            Text(value)
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
        }
    }
}
