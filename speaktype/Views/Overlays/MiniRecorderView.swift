import SwiftUI
import Combine
import AVFoundation
import CoreMedia

struct MiniRecorderView: View {
    @ObservedObject private var audioRecorder = AudioRecordingService.shared
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
        HStack(spacing: 0) {
            // 1. Mic Button (Left)
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
            
            Spacer()
            
            // 2. Waveform (Center)
            HStack(spacing: 3) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3, height: 10) // Small base height
                        .scaleEffect(y: isListening ? min(CGFloat(1.0 + (Double(audioRecorder.audioLevel) * 2.5)), 2.5) : 1.0, anchor: .center)
                        .opacity(isListening ? 0.9 : 0.3)
                        .animation(
                            isListening ? .easeInOut(duration: 0.1) : .default,
                            value: audioRecorder.audioLevel
                        )
                }
            }
            .frame(width: 30, height: 24, alignment: .center)
            
            Spacer()
            
            // 3. Model Selector (Right)
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "0E0F12").opacity(0.98)) // Refined Matte Black

                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .fontDesign(.rounded)
        .onReceive(NotificationCenter.default.publisher(for: .recordingStartRequested)) { _ in
            startRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingStopRequested)) { _ in
            stopAndTranscribe()
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
             let modelName = AIModel.availableModels.first(where: { $0.variant == selectedModel })?.name ?? selectedModel
             HistoryService.shared.addItem(
                transcript: text,
                duration: duration,
                audioFileURL: url,
                modelUsed: modelName,
                transcriptionTime: nil // Can add timing later if needed
             )
             
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
