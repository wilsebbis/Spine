import SwiftUI
import SwiftData

// MARK: - Reading Club View
// Create, join, and manage reading clubs.
// Clubs set a shared book and pace for group reading.

struct ReadingClubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clubs: [ReadingClub]
    @Query private var books: [Book]
    
    @State private var showingCreateClub = false
    @State private var selectedClub: ReadingClub?
    
    var body: some View {
        NavigationStack {
            Group {
                if clubs.isEmpty {
                    emptyState
                } else {
                    clubList
                }
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Reading Clubs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateClub = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateClub) {
                CreateClubSheet(books: books)
            }
        }
    }
    
    // MARK: - Club List
    
    private var clubList: some View {
        ScrollView {
            LazyVStack(spacing: SpineTokens.Spacing.sm) {
                ForEach(clubs) { club in
                    clubCard(club)
                }
            }
            .padding(SpineTokens.Spacing.md)
        }
    }
    
    private func clubCard(_ club: ReadingClub) -> some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: SpineTokens.Spacing.xxxs) {
                    Text(club.name)
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    if !club.clubDescription.isEmpty {
                        Text(club.clubDescription)
                            .font(SpineTokens.Typography.caption)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Member count
                HStack(spacing: SpineTokens.Spacing.xxxs) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(club.memberCount)")
                        .font(SpineTokens.Typography.caption2)
                }
                .foregroundStyle(SpineTokens.Colors.accentGold)
            }
            
            // Progress
            HStack(spacing: SpineTokens.Spacing.sm) {
                if let book = books.first(where: { $0.id == club.bookId }) {
                    // Book info
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        if let coverData = book.coverImageData,
                           let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 28, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(book.title)
                                .font(SpineTokens.Typography.caption2)
                                .foregroundStyle(SpineTokens.Colors.espresso)
                                .lineLimit(1)
                            Text("Unit \(club.currentUnit + 1) of \(book.unitCount)")
                                .font(.system(size: 10))
                                .foregroundStyle(SpineTokens.Colors.subtleGray)
                        }
                    }
                }
                
                Spacer()
                
                Text(club.createdAt.formatted(.relative(presentation: .named)))
                    .font(SpineTokens.Typography.caption2)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
        }
        .padding(SpineTokens.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpineTokens.Spacing.lg) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(SpineTokens.Colors.warmStone)
            
            Text("No Reading Clubs Yet")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Create a club to read together with friends. Set a shared pace and discuss each unit.")
                .font(SpineTokens.Typography.body)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.xl)
            
            SpineGlassButton("Create a Club", systemImage: "plus") {
                showingCreateClub = true
            }
            
            Spacer()
        }
    }
}

// MARK: - Create Club Sheet

struct CreateClubSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let books: [Book]
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedBookId: UUID?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Club Info") {
                    TextField("Club Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Choose a Book") {
                    let completedBooks = books.filter { $0.importStatus == .completed }
                    if completedBooks.isEmpty {
                        Text("Import a book first to create a club.")
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    } else {
                        ForEach(completedBooks) { book in
                            Button {
                                selectedBookId = book.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(book.title)
                                            .font(SpineTokens.Typography.headline)
                                            .foregroundStyle(SpineTokens.Colors.espresso)
                                        Text(book.author)
                                            .font(SpineTokens.Typography.caption)
                                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                                    }
                                    Spacer()
                                    if selectedBookId == book.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(SpineTokens.Colors.accentGold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createClub()
                    }
                    .disabled(name.isEmpty || selectedBookId == nil)
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
        }
    }
    
    private func createClub() {
        guard let bookId = selectedBookId else { return }
        let club = ReadingClub(
            name: name,
            clubDescription: description,
            bookId: bookId
        )
        modelContext.insert(club)
        try? modelContext.save()
        dismiss()
    }
}
