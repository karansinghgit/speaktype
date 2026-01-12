import SwiftUI
import AVKit
import CoreMedia
import UniformTypeIdentifiers

struct DashboardView: View {
    @Binding var selection: SidebarItem?
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    

    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base"
    @State private var sharedPlayer: AVPlayer?
    
    @State private var showFileImporter = false
    @State private var isTranscribing = false
    @State private var transcriptionStatus = ""
    
    // Computed Metrics
    var transcriptionCountToday: Int {
        historyService.items.filter { Calendar.current.isDateInToday($0.date) }.count
    }
    
    var totalWordsTranscribed: Int {
        historyService.items.reduce(0) { count, item in
            count + item.transcript.components(separatedBy: .whitespacesAndNewlines).count
        }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                HStack(spacing: 20) {
                    // ... (Left Column unchanged)
                    VStack(spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dashboard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Welcome back, User")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Stats Cards Row
                        HStack(spacing: 16) {
                            StatsCard(
                                title: "Transcriptions Today",
                                value: "\(transcriptionCountToday)",
                                icon: "waveform",
                                gradient: LinearGradient(colors: [.red.opacity(0.8), .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            StatsCard(
                                title: "Words Transcribed",
                                value: "\(totalWordsTranscribed)",
                                icon: "text.quote",
                                gradient: LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        }
                        
                        // Quick Start Card
                        QuickStartCard(
                            isRecording: audioRecorder.isRecording,
                            isTranscribing: isTranscribing,
                            statusText: transcriptionStatus,
                            onRecord: toggleRecording,
                            onImport: { showFileImporter = true }
                        )
                        
                        // Recent Transcriptions
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Transcriptions")
                                    .font(.headline)
                                Spacer()
                                Button("See All") {
                                    selection = .history
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                            
                            ScrollView {
                                VStack(spacing: 10) {
                                    if historyService.items.isEmpty {
                                        Text("No recent activity")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                            .padding()
                                    } else {
                                        ForEach(historyService.items.prefix(5)) { item in
                                            RecentItemRow(item: item)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column: Tutorials
                    if geometry.size.width > 800 {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tips & Tutorials")
                                .font(.headline)
                            
                            VideoPlayerView(player: sharedPlayer)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                TutorialLink(text: "How to record audio and transcribe")
                                TutorialLink(text: "Improving transcription accuracy")
                                TutorialLink(text: "Explore AI models for specific tasks")
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .frame(width: 300)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(16)
                    }
                }
                .padding(24)
            }

            

        }
        .background(Color.contentBackground)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
             // ... existing file importer logic
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
            if sharedPlayer == nil {
                if let url = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") {
                    sharedPlayer = AVPlayer(url: url)
                }
            }
            Task {
                // Initialize with user's selected model from Settings
                if !whisperService.isInitialized || whisperService.currentModelVariant != selectedModel {
                    try? await whisperService.loadModel(variant: selectedModel)
                }
            }
        }
        .onChange(of: selectedModel) { newValue in
            Task {
                try? await whisperService.loadModel(variant: newValue)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            Task {
                if let url = await audioRecorder.stopRecording() {
                     startTranscription(url: url)
                }
            }
        } else {
            audioRecorder.startRecording()
        }
    }
    
    private func handleFileSelection(url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: url, to: tempURL)
            startTranscription(url: tempURL)
        } catch {
            print("Error copying file: \(error)")
            startTranscription(url: url) // Fallback
        }
    }
    
    private func startTranscription(url: URL) {
        Task {
            isTranscribing = true
            transcriptionStatus = "Transcribing..."
            
            do {
                if !whisperService.isInitialized { try? await whisperService.initialize() }
                
                let text = try await whisperService.transcribe(audioFile: url)
                let duration = try await getAudioDuration(url: url)
                
                DispatchQueue.main.async {
                    historyService.addItem(transcript: text, duration: duration)
                    transcriptionStatus = "Done!"
                    isTranscribing = false
                    // Clear status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        transcriptionStatus = ""
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    transcriptionStatus = "Error"
                    isTranscribing = false
                }
            }
        }
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}

// MARK: - Components

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct QuickStartCard: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let statusText: String
    let onRecord: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Start")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Start a new audio recording to begin transcribing conversation instantly.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(statusText == "Error" ? .red : .yellow)
                        .padding(.top, 4)
                }
                
                Button(action: onImport) {
                    Label("Browse Files", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .padding(.top, 4)
            }
            
            Spacer()
            
            Button(action: onRecord) {
                ZStack {
                    if isTranscribing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, isRecording ? .white.opacity(0.2) : Color.appRed) // Outer ring effect if desired
                            .background(
                                Circle()
                                    .fill(isRecording ? Color.appRed : Color.clear)
                                    .frame(width: 40, height: 40) // Fill background when recording
                            )
                            .overlay(
                                Image(systemName: isRecording ? "square.fill" : "mic.fill") // Inner icon
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .opacity(isRecording ? 1 : 0) // Hide mic fill, show square
                            )
                        
                        // Let's stick to the user's simple mic icon style but functional logic
                        // Re-doing icon to match style exactly
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                             .resizable()
                             .symbolRenderingMode(.palette)
                             .foregroundStyle(.white, Color.appRed)
                             .frame(width: 56, height: 56)
                             .overlay(
                                isRecording ?
                                    Circle().stroke(Color.white, lineWidth: 2).scaleEffect(1.2).opacity(0.5)
                                : nil
                             )
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isTranscribing)
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.appRed.opacity(0.1), Color.clear], startPoint: .leading, endPoint: .trailing)
        )
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct RecentItemRow: View {
    let item: HistoryItem
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(Color.appRed)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.transcript.prefix(40) + "...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Text(formatDuration(item.duration))
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appRed.opacity(0.2))
                .cornerRadius(4)
                .foregroundStyle(Color.appRed)
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
}

struct TutorialLink: View {
    let text: String
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundStyle(.gray)
            Text(text)
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}

struct VideoPlayerView: View {
    let player: AVPlayer?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let player = player {
                    VideoPlayer(player: player)
                } else {
                    Color.black
                }
            }
            .frame(height: 160)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .overlay {
                if player == nil {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 8) {
                            Image(systemName: "play.circle")
                                .font(.largeTitle)
                            Text("Add 'tutorial.mp4' to Resources")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

struct CustomVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }
    
    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player != player {
            view.player = player
        }
    }
}
