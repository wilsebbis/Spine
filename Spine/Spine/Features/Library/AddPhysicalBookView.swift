import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Add Physical Book View
// Sheet for adding a real-life paper book to the library.
// Title + Author required, chapter count via stepper.
// Cover options: Camera, Photo Library, or Custom (color + emoji/glyph).

struct AddPhysicalBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var chapterCount = 10
    @State private var bookDescription = ""
    
    // Cover state
    @State private var coverMode: CoverMode = .none
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var showCamera = false
    @State private var selectedColorHex = "#2C3E50"
    @State private var selectedEmoji = "📚"
    @State private var selectedGlyph = ""
    @State private var showEmojiPicker = false
    @State private var showGlyphPicker = false
    
    enum CoverMode: String, CaseIterable {
        case none = "None"
        case photo = "Photo"
        case camera = "Camera"
        case custom = "Custom"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpineTokens.Spacing.lg) {
                    // Cover preview + options
                    coverPreview
                    coverOptionButtons
                    
                    // Book info
                    infoSection
                    
                    // Chapter count
                    chapterSection
                    
                    // Optional description
                    descriptionSection
                }
                .padding(.horizontal, SpineTokens.Spacing.md)
                .padding(.vertical, SpineTokens.Spacing.lg)
            }
            .background(SpineTokens.Colors.cream.ignoresSafeArea())
            .navigationTitle("Add Physical Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addBook() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    coverImageData = image.jpegData(compressionQuality: 0.8)
                    coverMode = .camera
                }
            }
        }
    }
    
    // MARK: - Cover Preview
    
    private var coverPreview: some View {
        ZStack {
            if let coverImageData, let uiImage = UIImage(data: coverImageData) {
                // Photo/Camera cover
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            } else if coverMode == .custom {
                // Custom color + emoji/glyph cover
                customCoverPreview
            } else {
                // Empty placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                        .fill(SpineTokens.Colors.warmStone.opacity(0.15))
                        .frame(width: 140, height: 210)
                    
                    VStack(spacing: SpineTokens.Spacing.xs) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(SpineTokens.Colors.accentGold)
                        
                        Text("Add Cover")
                            .font(SpineTokens.Typography.caption2)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }
        }
    }
    
    private var customCoverPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                .fill(Color(hex: selectedColorHex) ?? SpineTokens.Colors.espresso)
                .frame(width: 140, height: 210)
                .overlay(
                    RoundedRectangle(cornerRadius: SpineTokens.Radius.medium)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            VStack(spacing: SpineTokens.Spacing.sm) {
                if !selectedGlyph.isEmpty {
                    Image(systemName: selectedGlyph)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                if !selectedEmoji.isEmpty {
                    Text(selectedEmoji)
                        .font(.system(size: 42))
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
    
    // MARK: - Cover Option Buttons
    
    private var coverOptionButtons: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            // Top row: Camera, Photo Library
            HStack(spacing: SpineTokens.Spacing.sm) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(SpineTokens.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(
                            coverMode == .camera
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.warmStone.opacity(0.12)
                        )
                        .foregroundStyle(coverMode == .camera ? .white : SpineTokens.Colors.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                }
                
                // Photo library
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .font(SpineTokens.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(
                            coverMode == .photo
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.warmStone.opacity(0.12)
                        )
                        .foregroundStyle(coverMode == .photo ? .white : SpineTokens.Colors.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            coverImageData = data
                            coverMode = .photo
                        }
                    }
                }
                
                // Custom cover
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        coverMode = .custom
                        coverImageData = nil
                    }
                } label: {
                    Label("Custom", systemImage: "paintpalette.fill")
                        .font(SpineTokens.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(
                            coverMode == .custom
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.warmStone.opacity(0.12)
                        )
                        .foregroundStyle(coverMode == .custom ? .white : SpineTokens.Colors.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
                }
            }
            
            // Custom cover options (color, emoji, glyph)
            if coverMode == .custom {
                customCoverOptions
            }
        }
    }
    
    // MARK: - Custom Cover Options
    
    private var customCoverOptions: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.md) {
            // Color picker
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                Text("Cover Color")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.espresso)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        ForEach(coverColors, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .gray)
                                        .frame(width: 36, height: 36)
                                    
                                    if selectedColorHex == hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2.5)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Emoji picker
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                HStack {
                    Text("Emoji")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Spacer()
                    
                    if !selectedEmoji.isEmpty {
                        Button("Clear") {
                            selectedEmoji = ""
                        }
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SpineTokens.Spacing.xs) {
                        ForEach(coverEmojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = selectedEmoji == emoji ? "" : emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .padding(4)
                                    .background(
                                        selectedEmoji == emoji
                                            ? SpineTokens.Colors.accentGold.opacity(0.2)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            
            // Glyph picker
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                HStack {
                    Text("Glyph Icon")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Spacer()
                    
                    if !selectedGlyph.isEmpty {
                        Button("Clear") {
                            selectedGlyph = ""
                        }
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SpineTokens.Spacing.sm) {
                        ForEach(coverGlyphs, id: \.self) { glyph in
                            Button {
                                selectedGlyph = selectedGlyph == glyph ? "" : glyph
                            } label: {
                                Image(systemName: glyph)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(
                                        selectedGlyph == glyph
                                            ? SpineTokens.Colors.accentGold
                                            : SpineTokens.Colors.espresso
                                    )
                                    .frame(width: 40, height: 40)
                                    .background(
                                        selectedGlyph == glyph
                                            ? SpineTokens.Colors.accentGold.opacity(0.15)
                                            : SpineTokens.Colors.warmStone.opacity(0.08)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .padding(SpineTokens.Spacing.md)
        .background(SpineTokens.Colors.warmStone.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(spacing: SpineTokens.Spacing.sm) {
            TextField("Book Title", text: $title)
                .font(SpineTokens.Typography.body)
                .padding(SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.warmStone.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
            
            TextField("Author", text: $author)
                .font(SpineTokens.Typography.body)
                .padding(SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.warmStone.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        }
    }
    
    // MARK: - Chapter Count Section
    
    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text("Number of Chapters")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            HStack {
                Button {
                    if chapterCount > 1 { chapterCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                Text("\(chapterCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(SpineTokens.Colors.espresso)
                    .frame(minWidth: 50)
                
                Button {
                    if chapterCount < 200 { chapterCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
                
                Spacer()
                
                // Quick presets
                HStack(spacing: SpineTokens.Spacing.xs) {
                    ForEach([10, 20, 30, 50], id: \.self) { preset in
                        Button("\(preset)") {
                            chapterCount = preset
                        }
                        .font(SpineTokens.Typography.caption2)
                        .padding(.horizontal, SpineTokens.Spacing.sm)
                        .padding(.vertical, SpineTokens.Spacing.xxxs)
                        .background(
                            chapterCount == preset
                                ? SpineTokens.Colors.accentGold
                                : SpineTokens.Colors.warmStone.opacity(0.15)
                        )
                        .foregroundStyle(
                            chapterCount == preset ? .white : SpineTokens.Colors.espresso
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(SpineTokens.Spacing.sm)
            .background(SpineTokens.Colors.warmStone.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
            Text("Notes (optional)")
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            TextField("What's this book about?", text: $bookDescription, axis: .vertical)
                .lineLimit(3...6)
                .font(SpineTokens.Typography.body)
                .padding(SpineTokens.Spacing.sm)
                .background(SpineTokens.Colors.warmStone.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.small))
        }
    }
    
    // MARK: - Add Book
    
    private func addBook() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let book = Book(
            title: trimmedTitle,
            author: author.trimmingCharacters(in: .whitespaces),
            totalChapters: chapterCount,
            bookDescription: bookDescription,
            coverImageData: coverImageData,
            coverColorHex: coverMode == .custom ? selectedColorHex : nil,
            coverEmoji: coverMode == .custom && !selectedEmoji.isEmpty ? selectedEmoji : nil,
            coverGlyph: coverMode == .custom && !selectedGlyph.isEmpty ? selectedGlyph : nil
        )
        
        modelContext.insert(book)
        
        // Create ReadingProgress
        let progress = ReadingProgress(book: book)
        modelContext.insert(progress)
        book.readingProgress = progress
        
        try? modelContext.save()
        
        AnalyticsService.shared.log(.bookImportCompleted, properties: [
            "bookTitle": trimmedTitle,
            "sourceType": "physical",
            "chapters": String(chapterCount),
            "coverMode": coverMode.rawValue
        ])
        
        dismiss()
    }
    
    // MARK: - Data
    
    private let coverColors: [String] = [
        "#2C3E50", "#1A1A2E", "#16213E",   // Dark blues/navy
        "#0F3460", "#533483", "#5C2D91",    // Deep purple
        "#8B0000", "#C41E3A", "#800020",    // Reds/burgundy
        "#2D5016", "#1B4332", "#3A5A40",    // Greens
        "#B8860B", "#D4A017", "#C19A6B",    // Golds/tan
        "#4A4A4A", "#2F2F2F", "#1A1A1A",    // Grays/black
        "#E8B4B8", "#A8DADC", "#FFE4C4",    // Pastels
    ]
    
    private let coverEmojis: [String] = [
        "📚", "📖", "📕", "📗", "📘", "📙",
        "⚡", "🔥", "✨", "💡", "🌟", "🎯",
        "🧠", "💪", "🚀", "🎭", "🗡️", "🏰",
        "🌍", "🌊", "🏔️", "🌙", "☀️", "🌌",
        "❤️", "💀", "👁️", "🦅", "🐉", "🦁",
        "⏳", "🧭", "🗺️", "🔮", "📿", "🎵",
    ]
    
    private let coverGlyphs: [String] = [
        "bolt.fill", "flame.fill", "sparkles", "star.fill",
        "heart.fill", "book.fill", "leaf.fill", "moon.fill",
        "sun.max.fill", "cloud.fill", "drop.fill", "wind",
        "mountain.2.fill", "globe.americas.fill", "airplane",
        "crown.fill", "shield.fill", "flag.fill",
        "lightbulb.fill", "brain.head.profile", "eye.fill",
        "hand.raised.fill", "figure.walk", "music.note",
        "pencil", "paintbrush.fill", "camera.fill",
    ]
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction
        
        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
