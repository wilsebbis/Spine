import SwiftUI

// MARK: - Explain Paragraph Sheet
// Shows a plain-language explanation of a dense passage, powered by on-device AI.

struct ExplainParagraphSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let paragraphText: String
    let bookTitle: String
    
    @State private var explanation: String = ""
    @State private var isLoading = true
    @State private var error: String?
    
    private let aiService: AIServiceProtocol = FoundationModelService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.lg) {
                    // Original passage
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("Original Passage")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .textCase(.uppercase)
                        
                        Text(paragraphText)
                            .font(SpineTokens.Typography.readerSerif(size: 14))
                            .foregroundStyle(SpineTokens.Colors.espresso.opacity(0.7))
                            .lineLimit(6)
                            .padding(SpineTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SpineTokens.Colors.softGold)
                            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    }
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                        Text("In Plain Language")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .textCase(.uppercase)
                        
                        if isLoading {
                            HStack(spacing: SpineTokens.Spacing.sm) {
                                ProgressView()
                                    .tint(SpineTokens.Colors.accentGold)
                                Text("Analyzing passage…")
                                    .font(SpineTokens.Typography.caption)
                                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                        } else if let error {
                            Text(error)
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.streakFlame)
                        } else {
                            Text(explanation)
                                .font(SpineTokens.Typography.body)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(SpineTokens.Spacing.lg)
            }
            .navigationTitle("Explain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await loadExplanation()
        }
    }
    
    private func loadExplanation() async {
        guard FoundationModelService.isAvailable else {
            error = "AI features require a device that supports Apple Intelligence."
            isLoading = false
            return
        }
        
        do {
            explanation = try await aiService.explainParagraph(paragraphText, bookTitle: bookTitle)
            isLoading = false
            AnalyticsService.shared.log(.paragraphExplained)
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}
