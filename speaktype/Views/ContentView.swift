import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    @State private var transcribedText: String = ""
    @State private var isTranscribing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SpeakType Integration Test")
                .font(.headline)
            
            // Audio Recording Section
            if audioRecorder.isRecording {
                Button("Stop & Transcribe") {
                    if let url = audioRecorder.stopRecording() {
                        print("Recorded to: \(url)")
                        Task {
                            isTranscribing = true
                            do {
                                transcribedText = try await whisperService.transcribe(audioFile: url)
                            } catch {
                                transcribedText = "Error: \(error.localizedDescription)"
                            }
                            isTranscribing = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button("Start Recording") {
                    transcribedText = "" // Clear previous
                    audioRecorder.requestPermission()
                    audioRecorder.startRecording()
                }
                .buttonStyle(.bordered)
            }
            
            // Whisper Initialization
            if !whisperService.isInitialized {
                Button("Initialize Whisper") {
                    Task {
                        try? await whisperService.initialize()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Transcription Output
            VStack(alignment: .leading) {
                Text("Transcription:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isTranscribing {
                    ProgressView("Transcribing...")
                } else {
                    Text(transcribedText.isEmpty ? "No text yet" : transcribedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Clipboard Actions
            HStack {
                Button("Copy Text") {
                    ClipboardService.shared.copy(text: transcribedText)
                }
                .disabled(transcribedText.isEmpty)
                
                Button("Paste (Simulate Cmd+V)") {
                    ClipboardService.shared.paste()
                }
                .disabled(transcribedText.isEmpty)
            }
            
            Text("Status: \(whisperService.isInitialized ? "Whisper Ready" : "Whisper Idle")")
                .font(.caption)
                .foregroundStyle(whisperService.isInitialized ? .green : .orange)
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            // HotkeyService removed in favor of KeyboardShortcuts defined in App
        }
    }
}

#Preview {
    ContentView()
}
