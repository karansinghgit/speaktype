import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showDeleteAlert = false
    @State private var expandedItemId: UUID? = nil
    @State private var showCopyToast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History")
                            .font(Typography.displayLarge)
                            .foregroundStyle(Color.textPrimary)
                        
                        if !historyService.items.isEmpty {
                            Text("\(historyService.items.count) transcriptions")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !historyService.items.isEmpty {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Clear All")
                            }
                            .font(Typography.labelSmall)
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
                
                if historyService.items.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.textMuted.opacity(0.4))
                        
                        VStack(spacing: 8) {
                            Text("No transcriptions yet")
                                .font(Typography.displaySmall)
                                .foregroundStyle(Color.textPrimary)
                            
                            Text("Press ⌘+Shift+Space to start recording")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    // History items as individual cards
                    VStack(spacing: 16) {
                        ForEach(historyService.items) { item in
                            HistoryCard(
                                item: item,
                                isExpanded: expandedItemId == item.id,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                                },
                                onCopy: { copyToClipboard(text: item.transcript) },
                                audioPlayer: audioPlayer
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopyToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentBlue)
                    Text("Text Copied")
                        .font(Typography.labelMedium)
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

// MARK: - History Card Component

struct HistoryCard: View {
    let item: HistoryItem
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    @ObservedObject var audioPlayer: AudioPlayerService
    @State private var isHovered = false
    
    var wordCount: Int {
        item.transcript.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: 16) {
                    // Date badge
                    VStack(alignment: .center, spacing: 2) {
                        Text(item.date.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.textPrimary)
                        Text(item.date.formatted(.dateTime.month(.abbreviated)))
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                            .textCase(.uppercase)
                    }
                    .frame(width: 48)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Transcript preview
                        Text(item.transcript)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                            .lineSpacing(4)
                        
                        // Metadata
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(item.date.formatted(date: .omitted, time: .shortened))
                            }
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                            
                            Text("•")
                                .font(Typography.captionSmall)
                                .foregroundStyle(Color.textMuted.opacity(0.5))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "text.word.spacing")
                                    .font(.system(size: 10))
                                Text("\(wordCount) words")
                            }
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                            
                            Text("•")
                                .font(Typography.captionSmall)
                                .foregroundStyle(Color.textMuted.opacity(0.5))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                Text(formatDurationShort(item.duration))
                            }
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                        }
                    }
                    
                    Spacer()
                    
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Full transcript
                        Text(item.transcript)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                            .lineSpacing(6)
                        
                        // Actions row
                        HStack(spacing: 12) {
                            Button(action: onCopy) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                    Text("Copy")
                                        .font(Typography.labelMedium)
                                }
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.bgHover)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            
                            if let audioURL = item.audioFileURL {
                                Button(action: {
                                    if audioPlayer.isPlaying {
                                        audioPlayer.pause()
                                    } else {
                                        audioPlayer.play()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 12))
                                        Text(audioPlayer.isPlaying ? "Pause" : "Play Audio")
                                            .font(Typography.labelMedium)
                                    }
                                    .foregroundStyle(Color.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.bgHover)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([audioURL])
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 12))
                                        Text("Show in Finder")
                                            .font(Typography.labelMedium)
                                    }
                                    .foregroundStyle(Color.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.bgHover)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Audio waveform (if available)
                        if let audioURL = item.audioFileURL {
                            VStack(spacing: 12) {
                                Divider()
                                
                                WaveformView(
                                    audioURL: audioURL,
                                    currentTime: $audioPlayer.currentTime,
                                    duration: $audioPlayer.duration
                                )
                                .frame(height: 60)
                            }
                        }
                        
                        // Metadata
                        if item.modelUsed != nil {
                            Divider()
                            
                            HStack(spacing: 12) {
                                if let model = item.modelUsed {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cpu")
                                            .font(.system(size: 11))
                                        Text(model)
                                    }
                                    .font(Typography.captionSmall)
                                    .foregroundStyle(Color.textMuted)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered || isExpanded ? Color.border : Color.border.opacity(0.5), lineWidth: 1)
        )
        .cardShadow()
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDurationShort(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let mins = seconds / 60
            return "\(mins)m"
        }
    }
}
