import SwiftUI

// MARK: - Referral & Gifting View
// Lightweight scaffolding for viral growth.
// Referral: share a link, get premium days when friend joins.
// Gifting: buy premium for a friend.
// Both drive organic growth from existing engaged readers.

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var referralCode = "SPINE-\(String(UUID().uuidString.prefix(6)).uppercased())"
    @State private var showingShareSheet = false
    @State private var showingGiftFlow = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Hero
                    heroSection
                    
                    // Referral card
                    referralCard
                    
                    // Gift card
                    giftCard
                    
                    // Stats
                    statsSection
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.bottom, SpineTokens.Spacing.xxl)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [referralShareText])
            }
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(SpineTokens.Colors.accentGold.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
            
            Text("Read Together")
                .font(SpineTokens.Typography.largeTitle)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Invite friends to Spine and both of you earn free premium days.")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.md)
        }
        .padding(.top, SpineTokens.Spacing.md)
    }
    
    // MARK: - Referral Card
    
    private var referralCard: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            HStack {
                Text("Your Referral Code")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                Spacer()
            }
            
            // Code display
            HStack {
                Text(referralCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .tracking(2)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = referralCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            .padding(SpineTokens.Spacing.md)
            .background(SpineTokens.Colors.softGold)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            
            // Share button
            Button {
                showingShareSheet = true
            } label: {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.espresso)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
            }
            
            // How it works
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                stepRow(number: 1, text: "Share your code with a friend")
                stepRow(number: 2, text: "They join Spine and enter your code")
                stepRow(number: 3, text: "You both get 7 days of Premium free")
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(SpineTokens.Colors.accentGold.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SpineTokens.Colors.accentGold)
            }
            
            Text(text)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
    }
    
    // MARK: - Gift Card
    
    private var giftCard: some View {
        Button {
            showingGiftFlow = true
        } label: {
            HStack(spacing: SpineTokens.Spacing.md) {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gift Premium")
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text("Give a friend 1 month of Spine Premium")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(SpineTokens.Colors.warmStone)
            }
            .padding(SpineTokens.Spacing.md)
            .background(SpineTokens.Colors.cream)
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            Text("Your Impact")
                .font(SpineTokens.Typography.headline)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            HStack(spacing: SpineTokens.Spacing.lg) {
                impactStat(value: "0", label: "Friends invited")
                impactStat(value: "0", label: "Days earned")
                impactStat(value: "0", label: "Friends reading")
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.cream)
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
    
    private func impactStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(SpineTokens.Colors.accentGold)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SpineTokens.Colors.subtleGray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    private var referralShareText: String {
        "I'm reading the classics with Spine! 📚 Use my code \(referralCode) when you sign up and we'll both get 7 days of Premium free. https://getspine.app/r/\(referralCode)"
    }
}

// MARK: - UIKit Share Sheet Bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
