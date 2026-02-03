import SwiftUI
import AVKit
import CoreMedia
import UniformTypeIdentifiers
import AppKit

struct DashboardView: View {
    @Binding var selection: SidebarItem?
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var audioRecorder = AudioRecordingService()
    private var whisperService: WhisperService { WhisperService.shared }
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
        // Last 7 days including today
        return (0..<7).reversed().map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let count = historyService.items.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE" // Mon, Tue, Wed
            let dayStr = String(formatter.string(from: date).prefix(3))
            return (dayStr, count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Trial Banner - Hidden (logic kept for future use)
                // if !licenseManager.isPro {
                //     TrialBanner(status: trialManager.trialStatus)
                // }
                
                // Two horizontal boxes: Stats + Activity Chart
                HStack(alignment: .top, spacing: 20) {
                    // Left: Stats Card
                    StatsCard(
                        greeting: timeBasedGreeting,
                        wordCount: totalWordsTranscribed,
                        timeSaved: timeSavedMinutes,
                        todayCount: transcriptionCountToday,
                        allTimeCount: historyService.items.count
                    )
                    
                    // Right: Activity Chart Card
                    ActivityChartCard(weeklyData: weeklyData)
                }
                
                // Recent Transcriptions - Enhanced
                VStack(alignment: .leading, spacing: 16) {
                    // Header with actions
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recent transcriptions")
                                .font(Typography.displaySmall)
                                .foregroundStyle(Color.textPrimary)
                            
                            if !historyService.items.isEmpty {
                                Text("\(historyService.items.count) total transcriptions")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.textMuted)
                            }
                        }
                        
                        Spacer()
                        
                        if !historyService.items.isEmpty {
                            Button(action: { selection = .history }) {
                                HStack(spacing: 6) {
                                    Text("View all")
                                        .font(Typography.labelSmall)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if historyService.items.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.textMuted.opacity(0.5))
                            
                            VStack(spacing: 6) {
                                Text("No transcriptions yet")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(Color.textPrimary)
                                
                                Text("Press ⌘+Shift+Space to start recording")
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(historyService.items.prefix(5)) { item in
                                RecentTranscriptionRow(item: item)
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.border, lineWidth: 1)
                )
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

// MARK: - Stats Card

struct StatsCard: View {
    let greeting: String
    let wordCount: Int
    let timeSaved: Int
    let todayCount: Int
    let allTimeCount: Int
    
    var avgWordsPerTranscription: Int {
        allTimeCount > 0 ? wordCount / allTimeCount : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Greeting + Hero stat
            VStack(alignment: .leading, spacing: 12) {
                Text(greeting)
                    .font(Typography.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(wordCount)")
                        .font(.system(size: 64, weight: .light, design: .serif))
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("words transcribed")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.bottom, 10)
                }
                
                // Insight text
                if timeSaved > 0 {
                    Text("Saving you \(timeSaved) minutes of typing time")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textMuted)
                }
            }
            
            Divider()
            
            // Stats grid - 2x2
            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    StatBlock(value: "\(todayCount)", label: "Transcriptions today", icon: "mic.fill")
                    Spacer()
                    StatBlock(value: "\(allTimeCount)", label: "Total transcriptions", icon: "tray.full.fill")
                }
                
                HStack(spacing: 24) {
                    StatBlock(value: "\(timeSaved)m", label: "Time saved typing", icon: "clock.fill")
                    Spacer()
                    StatBlock(value: "\(avgWordsPerTranscription)", label: "Avg words per note", icon: "textformat.123")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

// MARK: - Activity Chart Card

struct ActivityChartCard: View {
    let weeklyData: [(day: String, count: Int)]
    
    var totalThisWeek: Int {
        weeklyData.reduce(0) { $0 + $1.count }
    }
    
    var mostActiveDay: String {
        guard let maxDay = weeklyData.max(by: { $0.count < $1.count }) else {
            return "None"
        }
        return maxDay.count > 0 ? maxDay.day : "None"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("This week")
                    .font(Typography.displaySmall)
                    .foregroundStyle(Color.textPrimary)
                
                HStack(spacing: 6) {
                    Text("\(totalThisWeek)")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text("transcriptions")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                    
                    if totalThisWeek > 0 {
                        Text("•")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.textMuted.opacity(0.5))
                        
                        Text("Most active: \(mostActiveDay)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }
            
            Spacer()
            
            // Chart
            HStack(alignment: .bottom, spacing: 14) {
                let maxCount = max(weeklyData.map { $0.count }.max() ?? 1, 1)
                
                ForEach(Array(weeklyData.enumerated()), id: \.offset) { index, data in
                    VStack(spacing: 8) {
                        // Count label on top (only if > 0)
                        Text(data.count > 0 ? "\(data.count)" : "")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                            .frame(height: 14)
                        
                        // Bar
                        RoundedRectangle(cornerRadius: 5)
                            .fill(data.count > 0 ? Color.textPrimary : Color.border.opacity(0.3))
                            .frame(height: max(CGFloat(data.count) / CGFloat(maxCount) * 120, 8))
                        
                        // Day label
                        Text(data.day)
                            .font(Typography.captionSmall)
                            .foregroundStyle(data.count > 0 ? Color.textPrimary : Color.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: 420)
        .themedCard()
    }
}

// MARK: - Stat Block

struct StatBlock: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.textMuted)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(Color.textPrimary)
                
                Text(label)
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
            }
            
            Spacer()
        }
    }
}


// MARK: - Recent Transcription Row (Multi-line)

struct RecentTranscriptionRow: View {
    let item: HistoryItem
    @State private var isHovered = false
    @State private var showCopySuccess = false
    
    var wordCount: Int {
        item.transcript.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 32, height: 32)
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Transcript - multiple lines
                Text(item.transcript.isEmpty ? "Empty transcription" : item.transcript)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata row
                HStack(spacing: 12) {
                    // Time ago
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(timeAgo(item.date))
                    }
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
                    
                    // Word count
                    HStack(spacing: 4) {
                        Image(systemName: "text.word.spacing")
                            .font(.system(size: 11))
                        Text("\(wordCount) words")
                    }
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                        Text(formatDuration(item.duration))
                    }
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
                    
                    Spacer()
                    
                    // Quick actions
                    HStack(spacing: 8) {
                        // Copy button
                        Button(action: copyToClipboard) {
                            HStack(spacing: 4) {
                                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                Text(showCopySuccess ? "Copied" : "Copy")
                                    .font(Typography.captionSmall)
                            }
                            .foregroundStyle(showCopySuccess ? Color.accentSuccess : Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        
                        // Play audio button (if available)
                        if item.audioFileURL != nil {
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                    Text("Play")
                                        .font(Typography.captionSmall)
                                }
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.bgHover)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(isHovered ? 1 : 0.5)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.bgHover.opacity(0.7) : Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.transcript, forType: .string)
        
        withAnimation {
            showCopySuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let mins = seconds / 60
            let secs = seconds % 60
            return "\(mins)m \(secs)s"
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


// MARK: - Preference Key
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

