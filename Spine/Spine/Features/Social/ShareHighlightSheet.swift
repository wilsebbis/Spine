import SwiftUI

// MARK: - Share Highlight Sheet
// Creates a styled quote card from a highlight for sharing.
// Generates a beautiful visual card with book title and author context.

struct ShareHighlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let highlightText: String
    let bookTitle: String
    let bookAuthor: String
    
    @State private var cardImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.lg) {
                // Preview card
                quoteCard
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                
                // Share options
                if let image = cardImage {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(
                            "Quote from \(bookTitle)",
                            image: Image(uiImage: image)
                        )
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share as Image")
                                .font(SpineTokens.Typography.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    }
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                }
                
                // Share as text
                ShareLink(item: quoteShareText) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Share as Text")
                            .font(SpineTokens.Typography.headline)
                    }
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, SpineTokens.Spacing.lg)
                
                Spacer()
            }
            .background(SpineTokens.Colors.cream)
            .navigationTitle("Share Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            .onAppear {
                renderCardImage()
                AnalyticsService.shared.log(.highlightShared, properties: [
                    "bookTitle": bookTitle
                ])
            }
        }
    }
    
    // MARK: - Quote Card
    
    private var quoteCard: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            // Decorative quote mark
            Image(systemName: "quote.opening")
                .font(.system(size: 32))
                .foregroundStyle(SpineTokens.Colors.accentGold.opacity(0.5))
            
            Text(highlightText)
                .font(SpineTokens.Typography.readerSerif(size: 18))
                .foregroundStyle(SpineTokens.Colors.espresso)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            
            Divider()
                .frame(width: 40)
            
            VStack(spacing: SpineTokens.Spacing.xxxs) {
                Text(bookTitle)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .italic()
                
                Text("by \(bookAuthor)")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            // Spine branding
            HStack(spacing: SpineTokens.Spacing.xxs) {
                Image(systemName: "book.pages")
                    .font(.caption2)
                Text("Spine")
                    .font(SpineTokens.Typography.caption2)
            }
            .foregroundStyle(SpineTokens.Colors.subtleGray.opacity(0.6))
        }
        .padding(SpineTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [SpineTokens.Colors.cream, SpineTokens.Colors.parchment],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.xl))
        .shadow(color: SpineTokens.Shadows.medium, radius: 12, y: 4)
    }
    
    // MARK: - Share Text
    
    private var quoteShareText: String {
        """
        "\(highlightText)"
        
        — \(bookTitle) by \(bookAuthor)
        
        📚 Shared from Spine
        """
    }
    
    // MARK: - Render Card
    
    @MainActor
    private func renderCardImage() {
        let renderer = ImageRenderer(content: quoteCard.frame(width: 350))
        renderer.scale = 3.0
        cardImage = renderer.uiImage
    }
}
