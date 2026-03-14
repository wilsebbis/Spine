import SwiftUI
import SwiftData

// MARK: - Reaction Sheet
// Post-reading lightweight reaction prompt.
// "What did you think?" with emoji reactions, optional reflection, and quote save.

struct ReactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    let unit: ReadingUnit
    let onDismiss: () -> Void
    
    @State private var selectedReactions: Set<ReactionType> = []
    @State private var selectedVerdict: ReadingVerdict?
    @State private var favoriteQuote = ""
    @State private var showQuoteField = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Header
                    VStack(spacing: SpineTokens.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(SpineTokens.Colors.successGreen)
                        
                        Text("Unit Complete!")
                            .font(SpineTokens.Typography.title)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        Text(unit.title)
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                    
                    // Reaction chips
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                        Text("How did it feel?")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                            ForEach(ReactionType.allCases, id: \.self) { reaction in
                                reactionChip(reaction)
                            }
                        }
                    }
                    
                    // Verdict chips (Layer C)
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                        Text("Your verdict")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        SpineFlowLayout(spacing: SpineTokens.Spacing.xs) {
                            ForEach(ReadingVerdict.allCases, id: \.self) { verdict in
                                verdictChip(verdict)
                            }
                        }
                    }
                    
                    // Save favorite quote
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Button {
                            withAnimation { showQuoteField.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "quote.opening")
                                Text("Save a favorite quote")
                                    .font(SpineTokens.Typography.caption2)
                                Spacer()
                                Image(systemName: showQuoteField ? "chevron.up" : "chevron.down")
                            }
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                        }
                        
                        if showQuoteField {
                            // Show existing highlights to pick from
                            let highlights = book.sortedUnits.flatMap { $0.highlights }
                            
                            if !highlights.isEmpty {
                                Text("Pick from your highlights:")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: SpineTokens.Spacing.xs) {
                                        ForEach(highlights, id: \.id) { hl in
                                            Button {
                                                favoriteQuote = hl.selectedText
                                            } label: {
                                                Text("\"\(hl.selectedText.prefix(60))\(hl.selectedText.count > 60 ? "…" : "")\"")
                                                    .font(SpineTokens.Typography.caption2)
                                                    .foregroundStyle(
                                                        favoriteQuote == hl.selectedText
                                                            ? .white
                                                            : SpineTokens.Colors.espresso
                                                    )
                                                    .lineLimit(2)
                                                    .padding(.horizontal, SpineTokens.Spacing.sm)
                                                    .padding(.vertical, SpineTokens.Spacing.xs)
                                                    .frame(maxWidth: 200)
                                                    .background(
                                                        favoriteQuote == hl.selectedText
                                                            ? SpineTokens.Colors.accentGold
                                                            : Color(UIColor(hex: hl.colorHex) ?? .systemYellow).opacity(0.25)
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                                            }
                                        }
                                    }
                                }
                                
                                Text("Or type your own:")
                                    .font(SpineTokens.Typography.caption2)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                                    .padding(.top, SpineTokens.Spacing.xxs)
                            }
                            
                            TextField("Paste or type a quote…", text: $favoriteQuote, axis: .vertical)
                                .font(SpineTokens.Typography.readerSerif(size: 14))
                                .lineLimit(2...6)
                                .padding(SpineTokens.Spacing.sm)
                                .background(SpineTokens.Colors.softGold)
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                        }
                    }
                }
                .padding(.horizontal, SpineTokens.Spacing.lg)
                .padding(.bottom, SpineTokens.Spacing.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        dismiss()
                        onDismiss()
                    }
                    .font(SpineTokens.Typography.body)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
        }
        .onAppear {
            loadExistingReactions()
        }
    }
    
    // MARK: - Reaction Chip
    
    private func reactionChip(_ reaction: ReactionType) -> some View {
        let isSelected = selectedReactions.contains(reaction)
        
        return Button {
            if isSelected {
                selectedReactions.remove(reaction)
            } else {
                selectedReactions.insert(reaction)
            }
        } label: {
            HStack(spacing: SpineTokens.Spacing.xxs) {
                Text(reaction.emoji)
                Text(reaction.rawValue)
                    .font(SpineTokens.Typography.caption2)
            }
            .foregroundStyle(isSelected ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)
            .padding(.horizontal, SpineTokens.Spacing.sm)
            .padding(.vertical, SpineTokens.Spacing.xs)
            .background(
                isSelected ?
                SpineTokens.Colors.accentGold.opacity(0.2) :
                SpineTokens.Colors.warmStone.opacity(0.15)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? SpineTokens.Colors.accentGold : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
    
    // MARK: - Save
    
    private func saveAndDismiss() {
        // Save reactions
        for reactionType in selectedReactions {
            let reaction = Reaction(
                book: book,
                readingUnit: unit,
                reactionType: reactionType
            )
            if let v = selectedVerdict {
                reaction.verdictRaw = v.rawValue
            }
            modelContext.insert(reaction)
            
            AnalyticsService.shared.log(.reactionSaved, properties: [
                "type": reactionType.rawValue
            ])
        }
        
        // Save quote if provided
        if !favoriteQuote.isEmpty {
            let quote = QuoteSave(
                book: book,
                readingUnitId: unit.id,
                text: favoriteQuote
            )
            modelContext.insert(quote)
            
            AnalyticsService.shared.log(.quoteSaved)
        }
        
        try? modelContext.save()
        dismiss()
        onDismiss()
    }
    
    // MARK: - Load Existing
    
    /// Populate state from previously saved reactions so they persist across sheet reopens.
    private func loadExistingReactions() {
        // Load reactions for this unit
        let unitId = unit.id
        let existingReactions = book.reactions.filter { $0.readingUnit?.id == unitId }
        for reaction in existingReactions {
            if let type = reaction.reactionType {
                selectedReactions.insert(type)
            }
            if selectedVerdict == nil, let v = reaction.verdict {
                selectedVerdict = v
            }
        }
        
        // Load existing quote for this unit
        let existingQuotes = book.quoteSaves.filter { $0.readingUnitId == unitId }
        if let quote = existingQuotes.first {
            favoriteQuote = quote.text
            showQuoteField = true
        }
    }
    
    // MARK: - Verdict Chip
    
    private func verdictChip(_ verdict: ReadingVerdict) -> some View {
        let isSelected = selectedVerdict == verdict
        
        return Button {
            selectedVerdict = isSelected ? nil : verdict
        } label: {
            HStack(spacing: SpineTokens.Spacing.xxs) {
                Text(verdict.emoji)
                Text(verdict.rawValue)
                    .font(SpineTokens.Typography.caption2)
            }
            .foregroundStyle(isSelected ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)
            .padding(.horizontal, SpineTokens.Spacing.sm)
            .padding(.vertical, SpineTokens.Spacing.xs)
            .background(
                isSelected ?
                SpineTokens.Colors.accentGold.opacity(0.2) :
                SpineTokens.Colors.warmStone.opacity(0.15)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? SpineTokens.Colors.accentGold : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}
