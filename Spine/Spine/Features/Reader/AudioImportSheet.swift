import SwiftUI
import UniformTypeIdentifiers

// MARK: - Audio Import Sheet
// File picker + processing UI for importing audiobook MP3s.
// Shows transcription and alignment progress with status indicators.

struct AudioImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    let syncService: AudioSyncService
    let onSyncComplete: (ChapterTimings) -> Void
    
    @State private var showFilePicker = false
    @State private var importedFileName: String?
    @State private var isSyncing = false
    @State private var syncComplete = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SpineTokens.Spacing.lg) {
                // Header
                VStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                    
                    Text("Add Audiobook")
                        .font(SpineTokens.Typography.title)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    
                    Text("Import an MP3 or audio file to enable karaoke-style read-along highlighting.")
                        .font(SpineTokens.Typography.callout)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                }
                .padding(.top, SpineTokens.Spacing.xl)
                
                Divider()
                    .padding(.horizontal, SpineTokens.Spacing.lg)
                
                if isSyncing {
                    // Processing state
                    processingView
                } else if syncComplete {
                    // Success state
                    successView
                } else if let error = errorMessage {
                    // Error state
                    errorView(error)
                } else {
                    // Import state
                    importView
                }
                
                Spacer()
                
                // Info footer
                VStack(spacing: SpineTokens.Spacing.xs) {
                    HStack(spacing: SpineTokens.Spacing.xxs) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                        Text("All processing happens on-device")
                            .font(SpineTokens.Typography.caption2)
                    }
                    .foregroundStyle(SpineTokens.Colors.successGreen)
                    
                    Text("MP3, M4A, WAV supported • DRM-free files only")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.warmStone)
                }
                .padding(.bottom, SpineTokens.Spacing.lg)
            }
            .background(SpineTokens.Colors.cream)
            .navigationTitle("Audio Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType.mp3,
                    UTType.mpeg4Audio,
                    UTType.wav,
                    UTType.audio
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    // MARK: - Import View
    
    private var importView: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            if let fileName = importedFileName {
                // File selected, ready to process
                HStack(spacing: SpineTokens.Spacing.sm) {
                    Image(systemName: "music.note")
                        .foregroundStyle(SpineTokens.Colors.accentGold)
                    Text(fileName)
                        .font(SpineTokens.Typography.callout)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                        .lineLimit(1)
                }
                .padding(SpineTokens.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SpineTokens.Colors.softGold)
                .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.medium))
                .padding(.horizontal, SpineTokens.Spacing.lg)
                
                HStack(spacing: SpineTokens.Spacing.sm) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Choose Different")
                            .font(SpineTokens.Typography.callout)
                            .foregroundStyle(SpineTokens.Colors.subtleGray)
                            .padding(.horizontal, SpineTokens.Spacing.md)
                            .padding(.vertical, SpineTokens.Spacing.sm)
                            .background(SpineTokens.Colors.warmStone.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        startSync()
                    } label: {
                        HStack(spacing: SpineTokens.Spacing.xs) {
                            Image(systemName: "waveform")
                            Text("Sync Audio")
                        }
                        .font(SpineTokens.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpineTokens.Spacing.lg)
                        .padding(.vertical, SpineTokens.Spacing.sm)
                        .background(SpineTokens.Colors.accentGold)
                        .clipShape(Capsule())
                    }
                }
            } else {
                // No file yet
                Button {
                    showFilePicker = true
                } label: {
                    VStack(spacing: SpineTokens.Spacing.sm) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 28))
                        Text("Select Audio File")
                            .font(SpineTokens.Typography.headline)
                    }
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpineTokens.Spacing.xl)
                    .background(SpineTokens.Colors.accentGold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: SpineTokens.Radius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: SpineTokens.Radius.large)
                            .strokeBorder(
                                SpineTokens.Colors.accentGold.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                    )
                }
                .padding(.horizontal, SpineTokens.Spacing.lg)
            }
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            ProgressView(value: syncService.progress)
                .tint(SpineTokens.Colors.accentGold)
                .padding(.horizontal, SpineTokens.Spacing.xl)
            
            Text(syncService.statusMessage)
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("\(Int(syncService.progress * 100))%")
                .font(SpineTokens.Typography.caption2)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .monospacedDigit()
            
            // Pipeline steps
            VStack(alignment: .leading, spacing: SpineTokens.Spacing.xs) {
                pipelineStep("Transcribing speech", done: syncService.progress > 0.6)
                pipelineStep("Aligning with book text", done: syncService.progress > 0.85)
                pipelineStep("Building timing map", done: syncService.progress > 0.95)
            }
            .padding(.horizontal, SpineTokens.Spacing.xl)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SpineTokens.Colors.successGreen)
            
            Text("Audio Synced!")
                .font(SpineTokens.Typography.title)
                .foregroundStyle(SpineTokens.Colors.espresso)
            
            Text("Karaoke highlighting is now available while reading.")
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
            
            Button {
                dismiss()
            } label: {
                Text("Start Reading Along")
                    .font(SpineTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpineTokens.Spacing.xl)
                    .padding(.vertical, SpineTokens.Spacing.sm)
                    .background(SpineTokens.Colors.accentGold)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: SpineTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(SpineTokens.Colors.streakFlame)
            
            Text(message)
                .font(SpineTokens.Typography.callout)
                .foregroundStyle(SpineTokens.Colors.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpineTokens.Spacing.lg)
            
            HStack(spacing: SpineTokens.Spacing.sm) {
                Button("Try Again") {
                    errorMessage = nil
                    startSync()
                }
                .foregroundStyle(SpineTokens.Colors.accentGold)
                
                Button("Choose Different File") {
                    errorMessage = nil
                    showFilePicker = true
                }
                .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
        }
    }
    
    // MARK: - Pipeline Step
    
    private func pipelineStep(_ label: String, done: Bool) -> some View {
        HStack(spacing: SpineTokens.Spacing.sm) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(done ? SpineTokens.Colors.successGreen : SpineTokens.Colors.warmStone)
            Text(label)
                .font(SpineTokens.Typography.caption)
                .foregroundStyle(done ? SpineTokens.Colors.espresso : SpineTokens.Colors.subtleGray)
        }
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importedFileName = url.lastPathComponent
            do {
                _ = try syncService.importAudio(from: url, for: book)
            } catch {
                errorMessage = "Failed to import: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func startSync() {
        isSyncing = true
        errorMessage = nil
        
        Task {
            do {
                let timings = try await syncService.syncAudio(for: book)
                syncComplete = true
                isSyncing = false
                onSyncComplete(timings)
            } catch {
                errorMessage = error.localizedDescription
                isSyncing = false
            }
        }
    }
}
