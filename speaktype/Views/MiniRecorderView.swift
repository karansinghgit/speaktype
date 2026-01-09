import SwiftUI
import Combine
import AVFoundation
import CoreMedia

struct MiniRecorderView: View {
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    @State private var isListening = false
    @State private var isProcessing = false
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    
    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base"
    
    // Default Init for Preview
    init(onCommit: ((String) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onCommit = onCommit
        self.onCancel = onCancel
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // State Icon / Button
            Button(action: {
                handleHotkeyTrigger() // Use same toggle logic
            }) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.circle.fill") // Explicit Stop/Record icons
                        .font(.system(size: 28)) // Larger icon
                        .foregroundStyle(isListening ? Color.appRed : Color.white) // High contrast
                        .shadow(color: isListening ? Color.appRed.opacity(0.6) : .clear, radius: 8)
                }
            }
            .buttonStyle(.plain)
            
            // Listening Visualizer (Dots)
            HStack(spacing: 4) {
                ForEach(0..<12) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isListening ? Color.appRed : Color.white.opacity(0.3)) // Red when active
                        .frame(width: 4, height: 24) // Base height
                        .scaleEffect(y: isListening ? min(CGFloat(1.0 + (Double(audioRecorder.audioLevel) * 5.0)), 2.0) : 1.0, anchor: .center) // Bound scale
                        .opacity(isListening ? 1.0 : 0.3)
                        .animation(
                            isListening ? .easeInOut(duration: 0.1) : .default,
                            value: audioRecorder.audioLevel
                        )
                }
            }
            .frame(width: 120, height: 32) // Fixed frame
            
            // Actions
            HStack(spacing: 12) {
                 // Model Selector
                Menu {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(AIModel.availableModels) { model in
                            Text(model.name).tag(model.variant)
                        }
                    }
                } label: {
                    Image(systemName: "cpu")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .onChange(of: selectedModel) { oldValue, newValue in
                     switchModel(to: newValue)
                }
            
                Button(action: {
                    // Cancel / Close
                    if isListening {
                        _ = audioRecorder.stopRecording()
                        isListening = false
                    }
                    // Notify controller to cancel/close
                    onCancel?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.white.opacity(0.6))
                    .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black) // Pure black for high contrast
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1) // Subtle border
        )
        .fontDesign(.rounded)
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyTriggered)) { _ in
            handleHotkeyTrigger()
        }
        .onAppear {
            initializedService()
            // Window configuration is now handled by Controller
        }
    }
    
    // Initialize Whisper
    // Initialize Whisper
    private func initializedService() {
        Task {
            // Load the persisted model
            try? await whisperService.loadModel(variant: selectedModel)
        }
    }
    
    private func switchModel(to variant: String) {
        guard !isListening && !isProcessing else { return }
        Task {
            print("Switching model to: \(variant)")
            try? await whisperService.loadModel(variant: variant)
        }
    }
    
    // Main Workflow Logic
    private func handleHotkeyTrigger() {
        if isListening {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !isProcessing else { return }
        audioRecorder.startRecording()
        isListening = true
    }
    
    private func stopAndTranscribe() {
        guard let url = audioRecorder.stopRecording() else {
            isListening = false
            return
        }
        isListening = false
        isProcessing = true
        
        Task {
            // Transcribe
            do {
                if !whisperService.isInitialized {
                    try? await whisperService.loadModel(variant: selectedModel)
                }
                let text = try await whisperService.transcribe(audioFile: url)
                print("Transcription Result: '\(text)'")
                
                guard !text.isEmpty else {
                    print("Transcription was empty. Skipping paste.")
                    isProcessing = false
                    return
                }
                
                // Save to History
                let duration = getAudioDuration(url: url)
                HistoryService.shared.addItem(transcript: text, duration: duration)
                
                // Delegate Commit to Controller (Copy, Hide, Paste happens there)
                await MainActor.run {
                    onCommit?(text)
                }
                
            } catch {
                print("Transcription error: \(error)")
            }
            
            // Reset state
            await MainActor.run {
                 isProcessing = false
            }
        }
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
