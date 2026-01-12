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
    
    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base.en"
    
    // Default Init for Preview
    init(onCommit: ((String) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onCommit = onCommit
        self.onCancel = onCancel
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Record/Stop Button
            Button(action: {
                handleHotkeyTrigger()
            }) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isListening ? Color.appRed : Color.white)
                        .shadow(color: isListening ? Color.appRed.opacity(0.6) : .clear, radius: 8)
                }
            }
            .buttonStyle(.plain)
            
            // 2. Model Selector
            Menu {
                ForEach(AIModel.availableModels) { model in
                    Button(action: {
                        selectedModel = model.variant
                    }) {
                        HStack {
                            Text(model.name)
                            if selectedModel == model.variant {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "cpu")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .onChange(of: selectedModel) { newValue in
                 switchModel(to: newValue)
            }
            
            // 3. Cancel Button
            Button(action: {
                if isListening {
                    Task {
                         _ = await audioRecorder.stopRecording()
                         await MainActor.run {
                             isListening = false
                             onCancel?()
                         }
                    }
                } else {
                    onCancel?()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // 4. Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 4)
            
            // 5. Mini Visualizer (Right side, like picture)
            HStack(spacing: 3) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3, height: 10) // Small base height
                        .scaleEffect(y: isListening ? min(CGFloat(1.0 + (Double(audioRecorder.audioLevel) * 4.0)), 2.5) : 1.0, anchor: .center)
                        .opacity(isListening ? 0.9 : 0.3)
                        .animation(
                            isListening ? .easeInOut(duration: 0.1) : .default,
                            value: audioRecorder.audioLevel
                        )
                }
            }
            .frame(width: 30, height: 24, alignment: .center)
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
        if isListening {
            print("Model selection changed to \(variant) (deferred until transcription)")
            return
        }
        
        guard !isProcessing else { return }
        
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
        Task {
            guard let url = await audioRecorder.stopRecording() else {
                await MainActor.run { isListening = false }
                return
            }
            
            await MainActor.run {
                isListening = false
                isProcessing = true
            }
            
            await processRecording(url: url)
        }
    }

    private func processRecording(url: URL) async {
        do {
             if !whisperService.isInitialized || whisperService.currentModelVariant != selectedModel {
                 print("Loading deferred model: \(selectedModel)")
                 try? await whisperService.loadModel(variant: selectedModel)
             }
             
             let text = try await whisperService.transcribe(audioFile: url)
             print("Transcription Result: '\(text)'")
             
             guard !text.isEmpty else {
                 print("Transcription was empty. Skipping paste.")
                 await MainActor.run { isProcessing = false }
                 return
             }
             
             let duration = await getAudioDuration(url: url)
             HistoryService.shared.addItem(transcript: text, duration: duration)
             
             await MainActor.run {
                 onCommit?(text)
                 isProcessing = false
             }
        } catch {
             print("Transcription error: \(error)")
             await MainActor.run { isProcessing = false }
        }
    }
    
    private func getAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
}
