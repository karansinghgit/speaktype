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
        VStack(spacing: 30) {
            // Header removed for cleaner look
            Spacer().frame(height: 20)
            
            // Main Drop Zone / Action Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    // Make the entire area tappable for file picker
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
                        .font(.system(size: 50))
                        .foregroundStyle(.gray)
                    
                    Text("Drop audio or video file here")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Button(action: {
                        showFileImporter = true
                    }) {
                        Label("Upload Audio File", systemImage: "square.and.arrow.up")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Text("or")
                        .foregroundStyle(.gray)
                    
                    if audioRecorder.isRecording {
                        Button(action: {
                            Task {
                                if let url = await audioRecorder.stopRecording() {
                                    startTranscription(url: url)
                                }
                            }
                        }) {
                            Text("Stop Recording")
                                .frame(minWidth: 120)
                                .padding()
                                .background(Color.appRed)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if isTranscribing {
                        ProgressView("Transcribing...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    } else {
                        Button(action: {
                            audioRecorder.startRecording()
                        }) {
                            Text("Start Recording")
                                .frame(minWidth: 120)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !transcribedText.isEmpty {
                        ScrollView {
                            Text(transcribedText)
                                .padding()
                                .foregroundStyle(.white)
                        }
                        .frame(height: 100)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        
                        HStack {
                            Button("Copy Text") {
                                ClipboardService.shared.copy(text: transcribedText)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                            
                            Button("Paste (Simulate)") {
                                ClipboardService.shared.paste()
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .background(Color.contentBackground)
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
                HistoryService.shared.addItem(transcript: transcribedText, duration: duration)
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
