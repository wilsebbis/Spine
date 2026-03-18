import SwiftUI
import SwiftData

// MARK: - Review Editor View
// Allows the user to rate and review a finished book.

struct ReviewEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book
    
    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.xl) {
                    
                    // Book Header
                    HStack(alignment: .top, spacing: SpineTokens.Spacing.md) {
                        if let coverData = book.coverImageData, let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                        } else {
                            BookCoverPlaceholder(title: book.title, author: book.author, size: CGSize(width: 80, height: 120))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(SpineTokens.Typography.headline)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                            Text(book.author)
                                .font(SpineTokens.Typography.subheadline)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Rating Form
                    VStack(spacing: SpineTokens.Spacing.sm) {
                        Text("Tap to Rate")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                        
                        HStack(spacing: SpineTokens.Spacing.lg) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundStyle(index <= rating ? SpineTokens.Colors.accentGold : SpineTokens.Colors.warmStone)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            rating = index
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    }
                    
                    // Review TextField
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
                        Text("Diary Entry")
                            .font(SpineTokens.Typography.headline)
                            .foregroundStyle(SpineTokens.Colors.espresso)
                        
                        TextEditor(text: $reviewText)
                            .font(SpineTokens.Typography.body)
                            .frame(minHeight: 150)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                                    .stroke(SpineTokens.Colors.warmStone, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                }
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Log Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReview()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let progress = book.readingProgress {
                    self.rating = progress.rating ?? 0
                    self.reviewText = progress.reviewText ?? ""
                }
            }
        }
    }
    
    private func saveReview() {
        if book.readingProgress == nil {
            let progress = ReadingProgress(book: book)
            modelContext.insert(progress)
            book.readingProgress = progress
        }
        
        book.readingProgress?.rating = rating > 0 ? rating : nil
        book.readingProgress?.reviewText = reviewText.isEmpty ? nil : reviewText
        
        try? modelContext.save()
    }
}
