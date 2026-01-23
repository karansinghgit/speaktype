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
    @Environment(\.colorScheme) var colorScheme
    
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
        ScrollView {
            VStack(spacing: 24) {
                // Trial Banner
                if !licenseManager.isPro {
                    TrialBanner(status: trialManager.trialStatus)
                }
                
                // Header - Serif headline like Flow
                VStack(alignment: .leading, spacing: 8) {
                    Text(timeBasedGreeting)
                        .font(Typography.displaySmall)  // Serif
                        .foregroundStyle(Color.textPrimary)
                    Text("Here's your productivity overview.")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Main Content Layout
                ViewThatFits(in: .horizontal) {
                    // Wide Layout
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 24) {
                            ProductivityCard(
                                transcriptionCount: transcriptionCountToday,
                                wordsTranscribed: totalWordsTranscribed,
                                timeSaved: timeSavedMinutes,
                                weeklyData: weeklyData
                            )
                        }
                        
                        TipsCard()
                            .frame(width: 300)
                    }
                    
                    // Narrow Layout
                    VStack(spacing: 24) {
                        ProductivityCard(
                            transcriptionCount: transcriptionCountToday,
                            wordsTranscribed: totalWordsTranscribed,
                            timeSaved: timeSavedMinutes,
                            weeklyData: weeklyData
                        )
                        
                        TipsCard()
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Recent Transcriptions - Flow style
                VStack(alignment: .leading, spacing: 16) {
                    // Header with serif
                    Text("Recent transcriptions")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Color.textPrimary)
                    
                    if historyService.items.isEmpty {
                        Text("No transcriptions yet. Start speaking to create your first one.")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(historyService.items.prefix(5)) { item in
                                RecentTranscriptionRow(item: item)
                            }
                        }
                        
                        Button(action: { selection = .history }) {
                            Text("View all transcriptions")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.accentPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(24)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.border, lineWidth: 1)
                )
                .cardShadow()
            }
            .padding(20)
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

// MARK: - Productivity Card (Flow-style)

struct ProductivityCard: View {
    let transcriptionCount: Int
    let wordsTranscribed: Int
    let timeSaved: Int
    let weeklyData: [(day: String, count: Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with serif
            Text("Your productivity today")
                .font(Typography.displaySmall)
                .foregroundStyle(Color.textPrimary)
            
            // Description
            Text("You've transcribed \(wordsTranscribed) words, saving approximately \(timeSaved) minutes of typing.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)
            
            // Stats row - like Flow's snippet examples
            HStack(spacing: 12) {
                StatPill(label: "Transcriptions", value: "\(transcriptionCount)")
                StatPill(label: "Words", value: "\(wordsTranscribed)")
                StatPill(label: "Time saved", value: "\(timeSaved)m")
            }
            
            // Mini chart
            HStack(alignment: .bottom, spacing: 6) {
                let maxCount = max(weeklyData.map { $0.count }.max() ?? 1, 1)
                
                ForEach(weeklyData, id: \.day) { data in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentPrimary.opacity(data.count > 0 ? 1 : 0.2))
                            .frame(width: 24, height: max(CGFloat(data.count) / CGFloat(maxCount) * 50, 6))
                        
                        Text(data.day)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textMuted)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
        .cardShadow()
    }
}

// MARK: - Stat Pill (Flow-style)

struct StatPill: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.textMuted)
            
            Text("→")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textMuted)
        }
    }
}

// MARK: - Metric Card (Clean)

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textMuted)
                
                Text(value)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.bgCard)
        .overlay(
            Rectangle()
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Recent Transcription Row (Flow-style)

struct RecentTranscriptionRow: View {
    let item: HistoryItem
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview text in a pill
            Text(item.transcript.isEmpty ? "Empty" : String(item.transcript.prefix(30)))
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text("→")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
            
            // Full transcript preview
            Text(item.transcript.isEmpty ? "No content" : item.transcript)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            
            Spacer()
            
            // Time ago
            Text(timeAgo(item.date))
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.bgHover.opacity(0.5) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Tips Card (Flow-style)

struct TipsCard: View {
    @State private var isMaximized = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with serif
            Text("Quick start guide")
                .font(Typography.displaySmall)
                .foregroundStyle(Color.textPrimary)
            
            Text("Learn how to get the most out of SpeakType with our quick video tutorial.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)
            
            // Video
            if let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.border, lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Button(action: { isMaximized = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textPrimary)
                                .padding(8)
                                .background(Color.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    .sheet(isPresented: $isMaximized) {
                        ZStack {
                            Color.ink.ignoresSafeArea()
                            VideoPlayer(player: AVPlayer(url: videoURL))
                                .aspectRatio(16/9, contentMode: .fit)
                                
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: { isMaximized = false }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                            .padding(12)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .keyboardShortcut(.escape, modifiers: [])
                                }
                                .padding()
                                Spacer()
                            }
                        }
                        .frame(minWidth: 800, minHeight: 600)
                    }
            } else {
                // Placeholder with mic icon like Flow
                VStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.textMuted)
                    
                    Text("Take a quick note with your voice")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
        .cardShadow()
    }
}

// MARK: - Preference Key
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

