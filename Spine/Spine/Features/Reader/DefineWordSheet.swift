import SwiftUI

// MARK: - Define Word Sheet
// Shows a contextual word definition powered by on-device AI.
// Triggered from text selection in ReaderView.

struct DefineWordSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let word: String
    let context: String
    
    @State private var definition: String = ""
    @State private var isLoading = true
    @State private var error: String?
    
    private let aiService: AIServiceProtocol = FoundationModelService()
    
    var body: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            // Handle
            Capsule()
                .fill(SpineTokens.Colors.warmStone)
                .frame(width: 36, height: 4)
                .padding(.top, SpineTokens.Spacing.sm)
            
            // Word header
            VStack(spacing: SpineTokens.Spacing.xs) {
                Text(word)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                // Context snippet
                Text("\(contextSnippet)")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
                    .italic()
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpineTokens.Spacing.lg)
            }
            
            Divider()
                .padding(.horizontal, SpineTokens.Spacing.lg)
            
            // Definition content
            if isLoading {
                VStack(spacing: SpineTokens.Spacing.sm) {
                    ProgressView()
                        .tint(SpineTokens.Colors.accentGold)
                    Text("Analyzing context…")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error {
                VStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(SpineTokens.Colors.streakFlame)
                    Text(error)
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, SpineTokens.Spacing.lg)
            } else {
                ScrollView {
                    Text(definition)
                        .font(SpineTokens.Typography.body)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                }
            }
            
            Spacer()
            
            // Done button
            Button("Done") { dismiss() }
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.accentGold)
                .padding(.bottom, SpineTokens.Spacing.lg)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .task {
            await loadDefinition()
        }
    }
    
    // MARK: - Helpers
    
    private var contextSnippet: String {
        // Show ~60 chars around the word
        let range = context.range(of: word, options: .caseInsensitive) ?? context.startIndex..<context.startIndex
        let start = context.index(range.lowerBound, offsetBy: -30, limitedBy: context.startIndex) ?? context.startIndex
        let end = context.index(range.upperBound, offsetBy: 30, limitedBy: context.endIndex) ?? context.endIndex
        return String(context[start..<end])
    }
    
    private func loadDefinition() async {
        guard FoundationModelService.isAvailable else {
            error = "AI features require a device that supports Apple Intelligence."
            isLoading = false
            return
        }
        
        do {
            definition = try await aiService.defineWord(word, context: context)
            isLoading = false
            AnalyticsService.shared.log(.wordDefined, properties: ["word": word])
        } catch {
            self.error = "Could not generate definition. Try again later."
            isLoading = false
        }
    }
}
