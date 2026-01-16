import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showDeleteAlert = false
    @State private var expandedItemId: UUID? = nil
    @State private var showCopyToast = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                if !historyService.items.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Clear History", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if historyService.items.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Your transcriptions will appear here.")
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(historyService.items) { item in
                            VStack(alignment: .leading, spacing: 0) {
                                // Clickable Header
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedItemId == item.id {
                                            expandedItemId = nil
                                            audioPlayer.stop()
                                        } else {
                                            expandedItemId = item.id
                                            if let audioURL = item.audioFileURL {
                                                audioPlayer.loadAudio(from: audioURL)
                                            }
                                        }
                                    }
                                }) {
                                    HStack(spacing: 14) {
                                        // Checkbox instead of arrow
                                        Image(systemName: expandedItemId == item.id ? "checkmark.square.fill" : "square")
                                            .font(.title3)
                                            .foregroundStyle(expandedItemId == item.id ? Color.accentBlue : Color.textMuted)
                                        
                                        // Mic icon
                                        Image(systemName: "mic.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.accentRed)
                                            .frame(width: 28)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(item.transcript.prefix(80) + (item.transcript.count > 80 ? "..." : ""))
                                                .font(.body)
                                                .foregroundStyle(Color.textPrimary)
                                                .lineLimit(1)
                                            Text(item.date.formatted(date: .numeric, time: .shortened))
                                                .font(.subheadline)
                                                .foregroundStyle(Color.textMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        // VOICE badge
                                        Text("VOICE")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.badgeVoiceText)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.badgeVoiceBg)
                                            .cornerRadius(5)
                                        
                                        // Duration
                                        Text(formatDurationShort(item.duration))
                                            .font(.subheadline)
                                            .foregroundStyle(Color.textMuted)
                                            .monospacedDigit()
                                            .frame(minWidth: 40)
                                    }
                                    .padding(18)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                // Expanded Content
                                if expandedItemId == item.id {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Divider()
                                            .padding(.horizontal, 18)
                                        
                                        VStack(alignment: .leading, spacing: 20) {
                                            // Header with badges
                                            HStack(alignment: .top) {
                                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.textMuted)
                                                
                                                Spacer()
                                                
                                                Text(formatDuration(item.duration))
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.accentBlue)
                                                    .fontWeight(.medium)
                                            }
                                            
                                            // Badges row
                                            HStack {
                                                Text("Original")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 7)
                                                    .background(Color.accentBlue)
                                                    .foregroundStyle(.white)
                                                    .cornerRadius(6)
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    copyToClipboard(text: item.transcript)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 13))
                                                        Text("Copy")
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)
                                                    }
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 7)
                                                    .background(Color.accentBlue)
                                                    .foregroundStyle(.white)
                                                    .cornerRadius(6)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            
                                            // Transcript - BIGGER TEXT
                                            Text(item.transcript)
                                                .font(.title3)
                                                .foregroundStyle(Color.textPrimary)
                                                .textSelection(.enabled)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .lineSpacing(4)
                                                .padding(.vertical, 10)
                                            
                                            // Audio Playback Section - ALWAYS SHOW
                                            VStack(spacing: 14) {
                                                Divider()
                                                
                                                if let audioURL = item.audioFileURL {
                                                    // Recording label with time
                                                    HStack {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: "waveform")
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.textMuted)
                                                            Text("Recording")
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.textMuted)
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        Text(formatTime(audioPlayer.currentTime))
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.textMuted)
                                                            .monospacedDigit()
                                                    }
                                                    
                                                    // Waveform
                                                    WaveformView(
                                                        audioURL: audioURL,
                                                        currentTime: $audioPlayer.currentTime,
                                                        duration: $audioPlayer.duration
                                                    )
                                                    .frame(height: 70)
                                                    
                                                    // Playback Controls
                                                    HStack(spacing: 24) {
                                                        Button(action: {
                                                            NSWorkspace.shared.activateFileViewerSelecting([audioURL])
                                                        }) {
                                                            Image(systemName: "folder")
                                                                .font(.title2)
                                                                .foregroundStyle(Color.accentBlue) // Theme Blue (File/System)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Show in Finder")
                                                        
                                                        Spacer()
                                                        
                                                        Button(action: {
                                                            if audioPlayer.isPlaying {
                                                                audioPlayer.pause()
                                                            } else {
                                                                audioPlayer.play()
                                                            }
                                                        }) {
                                                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                                                .font(.largeTitle)
                                                                .foregroundStyle(Color.accentRed) // Theme Red (Playback/Action)
                                                        }
                                                        .buttonStyle(.plain)
                                                        
                                                        Spacer()
                                                        
                                                        Button(action: {
                                                            audioPlayer.seek(to: 0)
                                                        }) {
                                                            Image(systemName: "arrow.clockwise")
                                                                .font(.title2)
                                                                .foregroundStyle(Color.accentBlue) // Theme Blue (Navigation)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Restart")
                                                    }
                                                    .padding(.vertical, 10)
                                                } else {
                                                    // No audio file available
                                                    VStack(spacing: 12) {
                                                        Image(systemName: "waveform.slash")
                                                            .font(.largeTitle)
                                                            .foregroundStyle(Color.textMuted)
                                                        Text("No audio recording available")
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.textMuted)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 30)
                                                }
                                            }
                                            .padding(18)
                                            .background(Color.bgHover)
                                            .cornerRadius(12)
                                            
                                            Divider()
                                            
                                            // Audio Duration with icon
                                            HStack(spacing: 10) {
                                                Image(systemName: "waveform.circle")
                                                    .font(.body)
                                                    .foregroundStyle(Color.textMuted)
                                                Text("Audio Duration")
                                                    .font(.body)
                                                    .foregroundStyle(Color.textMuted)
                                                
                                                Spacer()
                                                
                                                Text(formatDuration(item.duration))
                                                    .font(.body)
                                                    .foregroundStyle(Color.textPrimary)
                                            }
                                            .padding(.top, 8)
                                            
                                            // Additional Metrics
                                            if item.modelUsed != nil || item.transcriptionTime != nil {
                                                VStack(alignment: .leading, spacing: 14) {
                                                    if let model = item.modelUsed {
                                                        HStack(spacing: 10) {
                                                            Image(systemName: "cpu")
                                                                .font(.body)
                                                                .foregroundStyle(Color.textMuted)
                                                            Text("Transcription Model")
                                                                .font(.body)
                                                                .foregroundStyle(Color.textMuted)
                                                            Spacer()
                                                            Text(model)
                                                                .font(.body)
                                                                .foregroundStyle(Color.textPrimary)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    
                                                    if let transcriptionTime = item.transcriptionTime {
                                                        HStack(spacing: 10) {
                                                            Image(systemName: "clock")
                                                                .font(.body)
                                                                .foregroundStyle(Color.textMuted)
                                                            Text("Transcription Time")
                                                                .font(.body)
                                                                .foregroundStyle(Color.textMuted)
                                                            Spacer()
                                                            Text(formatDuration(transcriptionTime))
                                                                .font(.body)
                                                                .foregroundStyle(Color.textPrimary)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.bottom, 18)
                                    }
                                }
                            }
                            .background(Color.bgCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.borderCard, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }

        .background(Color.clear) // Transparent to show main gradient
        .overlay(alignment: .bottom) {
            if showCopyToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentBlue) // Theme Blue (Success)
                    Text("Text Copied")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Material.ultraThinMaterial)
                .background(Color.black.opacity(0.8))
                .cornerRadius(24)
                .shadow(radius: 10)
                .padding(.bottom, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Clear All History?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                historyService.clearAll()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        withAnimation {
            showCopyToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
    
    private func formatDurationShort(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds) s"
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
