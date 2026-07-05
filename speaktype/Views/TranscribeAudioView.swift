import SwiftUI
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers

struct TranscribeAudioView: View {
    @StateObject private var audioRecorder = AudioRecordingService.shared
    private var transcription: TranscriptionManager { TranscriptionManager.shared }
    @AppStorage(ModelSelection.defaultsKey) private var selectedModel: String = ModelSelection.none
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage: String = "auto"
    @State private var transcribedText: String = ""
    @State private var transcriptionError: String?
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
            if let transcriptionError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.accentError)
                    Text(transcriptionError)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(Color.accentError.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
            }

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
                transcriptionError = "File selection failed: \(error.localizedDescription)"
            }
        }
        .onAppear {
            Task {
                if !transcription.isInitialized && !transcription.currentModelVariant.isEmpty {
                    try? await transcription.initialize()
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
            let recordingURL = try copyToRecordingsDirectory(url)
            
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            
            startTranscription(url: recordingURL)
        } catch {
            transcriptionError = "Could not import file: \(error.localizedDescription)"
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func validateAndTranscribe(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) || 
               provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                
                provider.loadFileRepresentation(forTypeIdentifier: UTType.content.identifier) { url, error in
                    if let url = url {
                        do {
                            let recordingURL = try copyToRecordingsDirectory(url)
                            
                            DispatchQueue.main.async {
                                startTranscription(url: recordingURL)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                transcriptionError = "Could not import dropped file: \(error.localizedDescription)"
                            }
                        }
                    } else if let error {
                        DispatchQueue.main.async {
                            transcriptionError = "Could not read dropped file: \(error.localizedDescription)"
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
            transcriptionError = nil
            transcribedText = ""
            do {
                try await ensureSelectedModelIsLoaded()
                transcribedText = try await transcription.transcribe(audioFile: url, language: transcriptionLanguage)
                // Save to History
                let duration = try await getAudioDuration(url: url)
                HistoryService.shared.addItem(transcript: transcribedText, duration: duration, audioFileURL: url)
            } catch {
                transcriptionError = error.localizedDescription
            }
            isTranscribing = false
        }
    }

    private func ensureSelectedModelIsLoaded() async throws {
        guard selectedModel != ModelSelection.none else {
            throw NSError(
                domain: "SpeakType", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No AI model selected. Download and select one in Settings \u{2192} AI Models first."
                ])
        }

        if !transcription.isInitialized || transcription.currentModelVariant != selectedModel {
            try await transcription.loadModel(variant: selectedModel)
        }
    }

    private func copyToRecordingsDirectory(_ sourceURL: URL) throws -> URL {
        let filename = sourceURL.lastPathComponent.isEmpty ? "imported-audio" : sourceURL.lastPathComponent
        let destinationURL = AudioRecordingService.recordingsDirectory()
            .appendingPathComponent("imported-\(UUID().uuidString)-\(filename)")
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        // Async duration check using AVURLAsset
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}
