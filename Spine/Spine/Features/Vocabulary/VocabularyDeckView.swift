import SwiftUI
import SwiftData

// MARK: - Vocabulary Deck View
// Your saved words from reading, organized by mastery level.
// A paperback can't help you learn and retain the vocabulary
// you encounter — this is one of Spine's core value-adds.

struct VocabularyDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyWord.createdAt, order: .reverse) private var words: [VocabularyWord]
    
    @State private var showingReview = false
    @State private var selectedFilter: VocabularyWord.Mastery?
    
    private var dueCount: Int {
        words.filter { $0.isDueForReview }.count
    }
    
    private var filteredWords: [VocabularyWord] {
        guard let filter = selectedFilter else { return words }
        return words.filter { $0.mastery == filter }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Review CTA
                    if dueCount > 0 {
                        reviewCard
                    }
                    
                    // Filter chips
                    filterChips
                    
                    // Word list
                    if filteredWords.isEmpty {
                        emptyState
                    } else {
                        wordList
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Vocabulary")
            .sheet(isPresented: $showingReview) {
                ReviewSessionView()
            }
        }
    }
    
    // MARK: - Review Card
    
    private var reviewCard: some View {
        Button { showingReview = true } label: {
            HStack(spacing: SpineTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SpineTokens.Colors.accentGold, SpineTokens.Colors.accentAmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Text("\(dueCount)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dueCount) words ready for review")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("Quick 2-minute review session")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
            .padding(SpineTokens.Spacing.md)
            .background(SpineTokens.Colors.softGold)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Filters
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpineTokens.Spacing.xs) {
                filterButton(label: "All", value: nil, count: words.count)
                
                ForEach(VocabularyWord.Mastery.allCases, id: \.self) { mastery in
                    filterButton(
                        label: "\(mastery.emoji) \(mastery.rawValue)",
                        value: mastery,
                        count: words.filter { $0.mastery == mastery }.count
                    )
                }
            }
        }
    }
    
    private func filterButton(label: String, value: VocabularyWord.Mastery?, count: Int) -> some View {
        let isSelected = selectedFilter == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = value
            }
        } label: {
            Text("\(label) (\(count))")
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(isSelected ? .white : SpineTokens.Colors.espresso)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? SpineTokens.Colors.espresso : SpineTokens.Colors.warmStone.opacity(0.15))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Word List
    
    private var wordList: some View {
        LazyVStack(spacing: SpineTokens.Spacing.sm) {
            ForEach(filteredWords) { word in
                wordRow(word)
            }
        }
    }
    
    private func wordRow(_ word: VocabularyWord) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            HStack {
                Text(word.word)
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Spacer()
                
                Text(word.mastery.emoji)
            }
            
            Text(word.definition)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.8))
                .lineLimit(2)
            
            if !word.contextSentence.isEmpty {
                Text("\"...  \(word.contextSentence.prefix(80))...\"")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .italic()
                    .lineLimit(2)
            }
            
            if let book = word.book {
                Text(book.title)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(word)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty
    
    private var emptyState: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Spacer().frame(height: 40)
            
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text("No saved words yet")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Tap on difficult words while reading to save them to your vocabulary deck.")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
        }
    }
}

// MARK: - Mastery CaseIterable

extension VocabularyWord.Mastery: CaseIterable {
    static var allCases: [VocabularyWord.Mastery] {
        [.new, .learning, .familiar, .mastered]
    }
}
