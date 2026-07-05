import Foundation
import Combine
import SwiftUI // For IndexSet operations if needed, though Foundation usually covers it, but error says missing import.

struct HistoryStatsEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let wordCount: Int
    let duration: TimeInterval
}

struct HistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let transcript: String
    let duration: TimeInterval
    let audioFileURL: URL?
    let modelUsed: String?
    let transcriptionTime: TimeInterval?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

class HistoryService: ObservableObject {
    static let shared = HistoryService()
    
    @Published var items: [HistoryItem] = []
    @Published private(set) var statsEntries: [HistoryStatsEntry] = []
    
    private let saveKey = "history_items"
    private let statsSaveKey = "history_stats_entries"

    /// Bump when the normalization rules change in a way stored transcripts
    /// should be re-run through. While it matches, launch skips re-normalizing
    /// the whole history (~30 regex passes per item, growing with usage).
    private static let normalizationVersionKey = "history_normalization_version"
    private static let normalizationVersion = 1

    private init() {
        loadStats()
        loadHistory()
        sweepOrphanedRecordings()
    }
    
    func addItem(transcript: String, duration: TimeInterval, audioFileURL: URL? = nil, modelUsed: String? = nil, transcriptionTime: TimeInterval? = nil) {
        let normalizedTranscript = WhisperService.normalizedTranscription(from: transcript)
        guard !normalizedTranscript.isEmpty else { return }

        let timestamp = Date()
        let wordCount = normalizedTranscript.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        let newItem = HistoryItem(
            id: UUID(),
            date: timestamp,
            transcript: normalizedTranscript,
            duration: duration,
            audioFileURL: audioFileURL,
            modelUsed: modelUsed,
            transcriptionTime: transcriptionTime
        )
        let statsEntry = HistoryStatsEntry(
            id: newItem.id,
            date: timestamp,
            wordCount: wordCount,
            duration: duration
        )
        items.insert(newItem, at: 0) // Newest first
        statsEntries.insert(statsEntry, at: 0)
        saveHistory()
        saveStats()
    }
    
    func deleteItem(at offsets: IndexSet, deleteAudioFile: Bool = true) {
        let itemsToDelete = offsets.compactMap { items.indices.contains($0) ? items[$0] : nil }
        items.remove(atOffsets: offsets)
        if deleteAudioFile {
            itemsToDelete.forEach(removeAudioFileIfNeeded(for:))
        }
        saveHistory()
    }
    
    func deleteItem(id: UUID, deleteAudioFile: Bool = true) {
        let itemToDelete = items.first { $0.id == id }
        items.removeAll { $0.id == id }
        if deleteAudioFile, let itemToDelete {
            removeAudioFileIfNeeded(for: itemToDelete)
        }
        saveHistory()
    }
    
    func clearAll() {
        let itemsToDelete = items
        items.removeAll()
        itemsToDelete.forEach(removeAudioFileIfNeeded(for:))
        saveHistory()
    }

    func totalWordCount() -> Int {
        statsEntries.reduce(0) { $0 + $1.wordCount }
    }
    
    func transcriptionCount(since startDate: Date? = nil) -> Int {
        filteredStatsEntries(since: startDate).count
    }
    
    func totalDuration(since startDate: Date? = nil) -> TimeInterval {
        filteredStatsEntries(since: startDate).reduce(0) { $0 + $1.duration }
    }
    
    func wordCount(on day: Date, calendar: Calendar = .current) -> Int {
        let startOfDay = calendar.startOfDay(for: day)
        return statsEntries
            .filter { calendar.isDate($0.date, inSameDayAs: startOfDay) }
            .reduce(0) { $0 + $1.wordCount }
    }
    
    func statsEntries(since startDate: Date) -> [HistoryStatsEntry] {
        filteredStatsEntries(since: startDate)
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(statsEntries) {
            UserDefaults.standard.set(encoded, forKey: statsSaveKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            let storedVersion = UserDefaults.standard.integer(
                forKey: Self.normalizationVersionKey)
            if storedVersion == Self.normalizationVersion {
                items = decoded
                migrateStatsIfNeeded(from: decoded)
                return
            }

            let normalizedItems = decoded.compactMap { item -> HistoryItem? in
                let normalizedTranscript = WhisperService.normalizedTranscription(
                    from: item.transcript)
                guard !normalizedTranscript.isEmpty else { return nil }

                guard normalizedTranscript != item.transcript else { return item }

                return HistoryItem(
                    id: item.id,
                    date: item.date,
                    transcript: normalizedTranscript,
                    duration: item.duration,
                    audioFileURL: item.audioFileURL,
                    modelUsed: item.modelUsed,
                    transcriptionTime: item.transcriptionTime
                )
            }

            items = normalizedItems

            if normalizedItems.count != decoded.count
                || zip(decoded, normalizedItems).contains(where: { $0.transcript != $1.transcript })
            {
                saveHistory()
            }

            migrateStatsIfNeeded(from: normalizedItems)
        }
        UserDefaults.standard.set(
            Self.normalizationVersion, forKey: Self.normalizationVersionKey)
    }

    /// Delete recordings in the app-managed Recordings directory that no
    /// history item references. Recordings whose history rows were pruned
    /// (decode failures, failed imports) otherwise accumulate forever at
    /// ~1.9 MB/min of dictation. Only touches our own file patterns, and only
    /// files older than a day, so an in-flight recording is never swept.
    private func sweepOrphanedRecordings() {
        let referenced = Set(items.compactMap { $0.audioFileURL?.standardizedFileURL.path })
        DispatchQueue.global(qos: .utility).async {
            let dir = AudioRecordingService.recordingsDirectory()
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            else { return }

            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            for file in files {
                let name = file.lastPathComponent
                guard name.hasPrefix("recording-") || name.hasPrefix("imported-") else {
                    continue
                }
                guard !referenced.contains(file.standardizedFileURL.path) else { continue }
                let modified = (try? file.resourceValues(
                    forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard let modified, modified < cutoff else { continue }
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsSaveKey),
           let decoded = try? JSONDecoder().decode([HistoryStatsEntry].self, from: data) {
            statsEntries = decoded.sorted { $0.date > $1.date }
        }
    }
    
    private func migrateStatsIfNeeded(from historyItems: [HistoryItem]) {
        guard statsEntries.isEmpty, !historyItems.isEmpty else { return }

        statsEntries = historyItems.map { item in
            HistoryStatsEntry(
                id: item.id,
                date: item.date,
                wordCount: item.transcript
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .count,
                duration: item.duration
            )
        }
        saveStats()
    }
    
    private func filteredStatsEntries(since startDate: Date?) -> [HistoryStatsEntry] {
        guard let startDate else { return statsEntries }
        return statsEntries.filter { $0.date >= startDate }
    }

    private func removeAudioFileIfNeeded(for item: HistoryItem) {
        guard let audioFileURL = item.audioFileURL else { return }
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else { return }
        try? FileManager.default.removeItem(at: audioFileURL)
    }

#if DEBUG
    func resetAllDataForTesting() {
        items = []
        statsEntries = []
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: statsSaveKey)
    }
#endif
}
