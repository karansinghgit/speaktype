import SwiftUI
import AVKit
import CoreMedia
import UniformTypeIdentifiers

struct DashboardView: View {
    @Binding var selection: SidebarItem?
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var audioRecorder = AudioRecordingService()
    @State private var whisperService = WhisperService()
    @State private var leftColumnHeight: CGFloat = 0

    
    // Trial & License
    @EnvironmentObject var trialManager: TrialManager
    @EnvironmentObject var licenseManager: LicenseManager
    
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

    var weeklyData: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        // Last 5 days including today
        return (0..<5).reversed().map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let count = historyService.items.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // Mon, Tue
            let dayStr = formatter.string(from: date).prefix(1).uppercased() // M, T
            return (String(dayStr), count)
        }
    }

    var body: some View {
        ZStack {
            // Background is now provided by MainView
            Color.clear.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Trial Banner (always show for non-Pro users)
                    if !licenseManager.isPro {
                        TrialBanner(status: trialManager.trialStatus)
                    }
                    
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
                    
                    // Main Content Layout
                    HStack(alignment: .top, spacing: 24) {
                        // Left Column: Stats & Graph
                        VStack(spacing: 24) {
                            // Main Productivity Card
                            ProductivityCard(
                                transcriptionCount: transcriptionCountToday,
                                wordsTranscribed: totalWordsTranscribed,
                                timeSaved: timeSavedMinutes,
                                weeklyData: weeklyData
                            )
                        }
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                        })
                        
                        // Right Column: Tips (Fixed Width, Height Matched)
                        TipsCard()
                            .frame(width: 300)
                            .frame(height: leftColumnHeight > 0 ? leftColumnHeight : nil)
                    }
                    .onPreferenceChange(HeightPreferenceKey.self) { height in
                        leftColumnHeight = height
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

// MARK: - New Productivity Card

struct ProductivityCard: View {
    let transcriptionCount: Int
    let wordsTranscribed: Int
    let timeSaved: Int
    let weeklyData: [(day: String, count: Int)]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 32) {
            // Left: Stats
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title)
                        .foregroundStyle(.red)
                    Text("Today's Productivity")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(transcriptionCount)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Transcriptions Today")
                            .font(.body)
                            .foregroundStyle(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("\(wordsTranscribed)")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("words")
                            .foregroundStyle(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        Text("≈")
                            .foregroundStyle(.gray)
                        Text("\(timeSaved) min")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("saved")
                            .foregroundStyle(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Right: Graph
            HStack(alignment: .bottom, spacing: 12) {
                let maxCount = weeklyData.map { $0.count }.max() ?? 1
                let normalizedMax = max(Double(maxCount), 5.0) // prevent div by zero and tiny bars
                
                ForEach(weeklyData, id: \.day) { data in
                    VStack {
                        // Bar
                        GeometryReader { geo in
                            let height = max(Double(data.count) / normalizedMax * geo.size.height, 10.0)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: height)
                                .frame(maxWidth: .infinity, alignment: .bottom)
                                .position(x: geo.size.width / 2, y: geo.size.height - height / 2)
                        }
                        .frame(width: 20, height: 100) // Fixed graph height
                        
                        // Label
                        Text(data.day)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .padding(32)
        .background(
            ZStack {
                Color.black.opacity(0.6)
                // subtle glow
                RadialGradient(
                    colors: [Color.red.opacity(0.2), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Top accent line
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .red.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .offset(y: 1)
        }
    }
}

// MARK: - Updated Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gray)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
         // Rectangular, darker
        .background(Color.black.opacity(0.4))
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Recent Transcription Row (Unchanged styling, ensuring correct layout)

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
            // Left border accent (like SpeedType)
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
        .frame(maxWidth: .infinity) // Allow full width in column
        // Updated Background to match ProductivityCard (Dark + Yellow Glow)
        .background(
            ZStack {
                Color.black.opacity(0.6)
                // subtle yellow glow for "Tips"
                RadialGradient(
                    colors: [Color.yellow.opacity(0.15), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(24) // Match ProductivityCard
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preference Key
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

