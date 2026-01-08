import SwiftUI
import AVFoundation
import CoreMedia

struct TranscribeAudioView: View {
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    @State private var transcribedText: String = ""
    @State private var isTranscribing = false
    
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
                
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 50))
                        .foregroundStyle(.gray)
                    
                    Text("Drop audio or video file here")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("or")
                        .foregroundStyle(.gray)
                    
                    if audioRecorder.isRecording {
                        Button(action: {
                            if let url = audioRecorder.stopRecording() {
                                startTranscription(url: url)
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
        .onAppear {
            Task {
                if !whisperService.isInitialized {
                    try? await whisperService.initialize()
                }
            }
        }
    }
    
    private func startTranscription(url: URL) {
        Task {
            isTranscribing = true
            do {
                transcribedText = try await whisperService.transcribe(audioFile: url)
                // Save to History
                let duration = getAudioDuration(url: url)
                HistoryService.shared.addItem(transcript: transcribedText, duration: duration)
            } catch {
                transcribedText = "Error: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        // Simple duration check using AVURLAsset
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
