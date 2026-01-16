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
    
    var timeSavedMinutes: Int {
        // Average typing speed: 40 WPM.
        // Time saved = (Words / 40) - (Duration / 60)
        // Simplified: Just typing time for positive reinforcement.
        return totalWordsTranscribed / 40
    }
    
    var totalDurationSeconds: TimeInterval {
        historyService.items.reduce(0) { $0 + $1.duration }
    }
    
    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default: return "Welcome back,"
        }
    }
    
    var body: some View {
        ZStack {
            // Background is now provided by MainView
            Color.clear.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(timeBasedGreeting)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textPrimary)
                        Text("Here's your productivity overview.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Split Layout: Metrics (Left) + Tips (Right)
                    HStack(alignment: .top, spacing: 24) {
                        // Left Column: Stats Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ], spacing: 20) {
                            // Card 1: Transcriptions Today
                            MetricCard(
                                title: "Transcriptions Today",
                                value: "\(transcriptionCountToday)",
                                unit: "",
                                icon: "waveform",
                                color: .accentRed
                            )
                            
                            // Card 2: Words Transcribed
                            MetricCard(
                                title: "Words Transcribed",
                                value: "\(totalWordsTranscribed)",
                                unit: "words",
                                icon: "doc.text",
                                color: .accentBlue
                            )
                            
                            // Card 3: Time Saved
                            MetricCard(
                                title: "Est. Time Saved",
                                value: formatTimeSaved(minutes: timeSavedMinutes),
                                unit: "",
                                icon: "clock.fill",
                                color: .accentBlue // Theme Blue (Time)
                            )
                            
                            // Card 4: Total Recording Time
                            MetricCard(
                                title: "Total Recorded",
                                value: formatDurationHighLevel(totalDurationSeconds),
                                unit: "",
                                icon: "mic.fill",
                                color: .accentRed // Theme Red (Recording)
                            )
                        }
                        
                        // Right Column: Tips Section
                        TipsCard()
                    }
                    
                    // Recent Transcriptions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transcriptions")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Button("See All") {
                                selection = .history
                            }
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .buttonStyle(.plain)
                        }
                        
                        if historyService.items.isEmpty {
                            Text("No recent activity")
                                .font(.subheadline)
                                .foregroundStyle(Color.textMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(historyService.items.prefix(5)) { item in
                                    RecentTranscriptionRow(item: item)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.bgCard)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.borderCard, lineWidth: 1)
                    )
                }
                .padding(20)
            }
        }
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
    
    // MARK: - Helpers
    
    private func formatTimeSaved(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1fh", hours)
        }
    }
    
    private func formatDurationHighLevel(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 60 {
            return "\(mins)m"
        } else {
            let hours = Double(mins) / 60.0
            return String(format: "%.1fh", hours)
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
            startTranscription(url: url)
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
                let modelName = AIModel.availableModels.first(where: { $0.variant == selectedModel })?.name ?? selectedModel
                
                DispatchQueue.main.async {
                    historyService.addItem(
                        transcript: text,
                        duration: duration,
                        audioFileURL: url,
                        modelUsed: modelName,
                        transcriptionTime: nil
                    )
                    transcriptionStatus = "Done!"
                    isTranscribing = false
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

// MARK: - Recent Transcription Row (SpeedCursor Style)

struct RecentTranscriptionRow: View {
    let item: HistoryItem
    
    private var itemIcon: String {
        if item.transcript.localizedCaseInsensitiveContains("music") {
            return "music.note"
        } else if item.transcript.isEmpty {
            return "doc.text"
        } else {
            return "mic.fill"
        }
    }
    
    private var itemTag: (text: String, color: Color, bg: Color)? {
        if item.transcript.localizedCaseInsensitiveContains("music") {
            return ("MUSIC", Color.badgeMusicText, Color.badgeMusicBg)
        } else if item.transcript.isEmpty || item.transcript.count < 10 {
            return ("INAUDIBLE", Color.badgeMutedText, Color.badgeMutedBg)
        } else {
            return ("VOICE", Color.badgeVoiceText, Color.badgeVoiceBg)
        }
    }
    
    private var accentColor: Color {
        if item.transcript.localizedCaseInsensitiveContains("music") {
            return Color.accentBlue
        } else {
            return Color.accentRed
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon - Larger
            Image(systemName: itemIcon)
                .font(.title3)
                .foregroundStyle(accentColor)
                .frame(width: 28)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.transcript.isEmpty ? "No transcript" : item.transcript)
                    .font(.body) // Larger font (was subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(item.date.formatted(date: .numeric, time: .shortened))
                    .font(.subheadline) // Larger font (was caption2)
                    .foregroundStyle(Color.textMuted)
            }
            
            Spacer()
            
            // Tag
            if let tag = itemTag {
                Text(tag.text)
                    .font(.system(size: 11, weight: .bold)) // Slightly larger tag
                    .foregroundStyle(tag.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tag.bg)
                    .cornerRadius(6)
            }
            
            // Duration
            Text(formatDuration(item.duration))
                .font(.subheadline) // Larger time
                .foregroundStyle(Color.textMuted)
                .monospacedDigit()
        }
        .padding(16) // Increased padding
        .background(Color.bgHover)
        .cornerRadius(12)
        .overlay(
            // Left border accent (like SpeedCursor)
            Rectangle()
                .fill(accentColor)
                .frame(width: 4) // Thicker accent
                .cornerRadius(2)
                .padding(.leading, 0),
            alignment: .leading
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds) s"
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium)) // Smaller Icon
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) { // Increased spacing
                Text(title)
                    .font(.title3) // Increased from headline
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2) // Allow wrapping
                    .minimumScaleFactor(0.8)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold)) // Smaller Value
                        .foregroundStyle(Color.textPrimary)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.title3)
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 110) // Rectangular shape
        .background(.ultraThinMaterial)
        .background(Color.bgCard.opacity(0.4))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}



// MARK: - Tips & Tutorial Card

struct TipsCard: View {
    @State private var isMaximized = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)
                Text("Tips & Tutorials")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
            }
            
            // Video Player
            ZStack {
                if let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") {
                     VideoPlayer(player: AVPlayer(url: videoURL))
                         .aspectRatio(16/9, contentMode: .fit)
                         .cornerRadius(12)
                         .overlay(alignment: .topTrailing) {
                             Button(action: { isMaximized = true }) {
                                 Image(systemName: "arrow.up.left.and.arrow.down.right")
                                     .font(.headline)
                                     .foregroundStyle(.white)
                                     .padding(8)
                                     .background(.ultraThinMaterial)
                                     .clipShape(Circle())
                             }
                             .buttonStyle(.plain)
                             .padding(8)
                             .help("Maximize Video")
                         }
                         .sheet(isPresented: $isMaximized) {
                             ZStack {
                                 Color.black.ignoresSafeArea()
                                 VideoPlayer(player: AVPlayer(url: videoURL))
                                     .aspectRatio(16/9, contentMode: .fit)
                                     .frame(maxWidth: .infinity, maxHeight: .infinity)
                                     
                                 // Close button for maximized view
                                 VStack {
                                     HStack {
                                         Spacer()
                                         Button(action: { isMaximized = false }) {
                                             Image(systemName: "xmark.circle.fill")
                                                 .font(.largeTitle)
                                                 .foregroundStyle(.white)
                                                 .padding()
                                         }
                                         .buttonStyle(.plain)
                                         .keyboardShortcut(.escape, modifiers: [])
                                     }
                                     Spacer()
                                 }
                             }
                             .frame(minWidth: 800, minHeight: 600) // Ensure reasonable size
                         }
                } else {
                    // Fallback if video not found
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                            .aspectRatio(16/9, contentMode: .fit)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.yellow)
                            Text("Video not found")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Text("Learn how to get the most out of SpeakType with our quick video guide.")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(24)
        .frame(width: 260) // Reduced width to give more space to Metrics
        .background(.ultraThinMaterial)
        .background(Color.bgCard.opacity(0.4))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
