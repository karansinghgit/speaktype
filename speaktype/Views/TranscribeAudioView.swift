import SwiftUI
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers

struct TranscribeAudioView: View {
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    @State private var transcribedText: String = ""
    @State private var isTranscribing = false
    @State private var showFileImporter = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Transcribe Audio")
                    .font(Typography.displayLarge)
                    .foregroundStyle(Color.textPrimary)
                
                Text("Upload an audio or video file to transcribe")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.top, 32)
            
            // Main Drop Zone / Action Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color.border)
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFileImporter = true
                    }
                    .onDrop(of: [.audio, .movie, .fileURL], isTargeted: nil) { providers in
                        validateAndTranscribe(providers: providers)
                        return true
                    }
                
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textMuted)
                    
                    Text("Drop audio or video file here")
                        .font(Typography.headlineSmall)
                        .foregroundStyle(Color.textPrimary)
                    
                    Button(action: {
                        showFileImporter = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Upload Audio File")
                        }
                    }
                    .buttonStyle(.stSecondary)
                    
                    Text("or")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textMuted)
                    
                    if audioRecorder.isRecording {
                        Button(action: {
                            Task {
                                if let url = await audioRecorder.stopRecording() {
                                    startTranscription(url: url)
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                Text("Stop Recording")
                            }
                            .font(Typography.bodyMedium)
                            .frame(minWidth: 140)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.accentError)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else if isTranscribing {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Transcribing...")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    } else {
                        Button(action: {
                            audioRecorder.startRecording()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                Text("Start Recording")
                            }
                        }
                        .buttonStyle(.stPrimary)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Transcription Result
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcription")
                        .font(Typography.headlineSmall)
                        .foregroundStyle(Color.textPrimary)
                    
                    ScrollView {
                        Text(transcribedText)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(height: 120)
                    .background(Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            ClipboardService.shared.copy(text: transcribedText)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                        }
                        .buttonStyle(.stSecondary)
                        
                        Button(action: {
                            ClipboardService.shared.paste()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste")
                            }
                        }
                        .buttonStyle(.stSecondary)
                    }
                }
                .themedCard()
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .background(Color.clear)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleFileSelection(url: url)
                }
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
        .onAppear {
            Task {
                if !whisperService.isInitialized {
                    try? await whisperService.initialize()
                }
            }
        }
    }
    
    private func handleFileSelection(url: URL) {
        // Access security scoped resource if needed (for file picker)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        
        // Create a copy or use the URL directly.
        // For simplicity in this context, we'll try to use it directly but ensure we stop accessing later if needed.
        // However, since startTranscription is async, we might lose access.
        // Better pattern: Copy to temp directory if possible, or keep access open during transcription.
        // Given WhisperKit might need file access, let's copy to a temp location to be safe and avoid scope issues.
        
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL) // Clean up if exists
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            
            startTranscription(url: tempURL)
        } catch {
            print("Error copying file: \(error)")
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            // Fallback: try original URL if copy fails
            startTranscription(url: url)
        }
    }
    
    private func validateAndTranscribe(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) || 
               provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                
                provider.loadFileRepresentation(forTypeIdentifier: UTType.content.identifier) { url, error in
                    if let url = url {
                        // LoadFileRepresentation gives us a temporary URL that might not persist.
                        // We should copy it immediately.
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        do {
                            try? FileManager.default.removeItem(at: tempURL)
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            
                            DispatchQueue.main.async {
                                startTranscription(url: tempURL)
                            }
                        } catch {
                            print("Error copying dropped file: \(error)")
                        }
                    }
                }
                return // Only handle the first valid file
            }
        }
    }
    
    private func startTranscription(url: URL) {
        Task {
            isTranscribing = true
            do {
                transcribedText = try await whisperService.transcribe(audioFile: url)
                // Save to History
                let duration = try await getAudioDuration(url: url)
                HistoryService.shared.addItem(transcript: transcribedText, duration: duration, audioFileURL: url)
            } catch {
                transcribedText = "Error: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        // Async duration check using AVURLAsset
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}
