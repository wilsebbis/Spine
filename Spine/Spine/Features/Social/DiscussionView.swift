import SwiftUI
import SwiftData

// MARK: - Discussion View
// Chapter-gated discussion threads. Users can only see and post in
// discussions for units they've already completed — spoiler-safe by design.
// Posts are persisted locally via SwiftData with optional CloudKit sync.

struct DiscussionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    let unit: ReadingUnit
    
    @Query private var allPosts: [LocalDiscussionPost]
    @State private var newPostText = ""
    @State private var isPosting = false
    
    /// Filter posts for this book + unit
    private var posts: [LocalDiscussionPost] {
        allPosts
            .filter { $0.book?.id == book.id && $0.unitOrdinal == unit.ordinal }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    init(book: Book, unit: ReadingUnit) {
        self.book = book
        self.unit = unit
        self._allPosts = Query()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Spoiler badge
                HStack(spacing: SpineTokens.Spacing.xxs) {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                    Text("Discussion for Unit \(unit.ordinal + 1) — spoiler-safe")
                        .font(SpineTokens.Typography.caption2)
                }
                .foregroundStyle(SpineTokens.Colors.successGreen)
                .padding(.vertical, SpineTokens.Spacing.xs)
                .padding(.horizontal, SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.successGreen.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, SpineTokens.Spacing.xs)
                
                // Posts
                if posts.isEmpty {
                    Spacer()
                    VStack(spacing: SpineTokens.Spacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(SpineTokens.Colors.warmStone)
                        Text("No discussion yet")
                            .font(SpineTokens.Typography.callout)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                        Text("Be the first to share your thoughts on this unit!")
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, SpineTokens.Spacing.xl)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: SpineTokens.Spacing.sm) {
                                ForEach(posts) { post in
                                    postCard(post)
                                        .id(post.id)
                                }
                            }
                            .padding(SpineTokens.Spacing.md)
                        }
                        .onAppear {
                            if let last = posts.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Compose bar
                HStack(spacing: SpineTokens.Spacing.sm) {
                    TextField("Share your thoughts…", text: $newPostText, axis: .vertical)
                        .font(SpineTokens.Typography.body)
                        .lineLimit(1...4)
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xs)
                        .background(SpineTokens.Colors.warmStone.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    
                    Button {
                        postDiscussion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                canPost ? SpineTokens.Colors.accentGold : SpineTokens.Colors.subtleGray
                            )
                    }
                    .disabled(!canPost || isPosting)
                }
                .padding(SpineTokens.Spacing.sm)
            }
            .background(SpineTokens.Colors.cream)
            .navigationTitle(unit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
        }
    }
    
    // MARK: - Post Card
    
    private func postCard(_ post: LocalDiscussionPost) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            HStack {
                // Author avatar
                Circle()
                    .fill(SpineTokens.Colors.accentGold)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(post.authorName.prefix(1)))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                
                Text(post.authorName)
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                Spacer()
                
                Text(post.createdAt.formatted(.relative(presentation: .named)))
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            Text(post.text)
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            // Like button
            HStack {
                Spacer()
                Button {
                    toggleLike(post)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLikedByUser ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(
                                post.isLikedByUser ? SpineTokens.Colors.streakFlame : SpineTokens.Colors.subtleGray
                            )
                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpineTokens.Colors.warmStone.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    // MARK: - Helpers
    
    private var canPost: Bool {
        newPostText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        && newPostText.count <= 280
    }
    
    private func toggleLike(_ post: LocalDiscussionPost) {
        if post.isLikedByUser {
            post.likeCount = max(0, post.likeCount - 1)
            post.isLikedByUser = false
        } else {
            post.likeCount += 1
            post.isLikedByUser = true
        }
        try? modelContext.save()
    }
    
    private func postDiscussion() {
        let text = newPostText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let post = LocalDiscussionPost(
            book: book,
            unitOrdinal: unit.ordinal,
            text: text
        )
        modelContext.insert(post)
        try? modelContext.save()
        
        newPostText = ""
        
        print("💬 Posted to discussion for unit \(unit.ordinal)")
        
        AnalyticsService.shared.log(.discussionViewed, properties: [
            "bookTitle": book.title,
            "unitOrdinal": String(unit.ordinal)
        ])
    }
}
