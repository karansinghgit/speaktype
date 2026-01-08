import Foundation
import Combine
import SwiftUI // For IndexSet operations if needed, though Foundation usually covers it, but error says missing import.

struct HistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let transcript: String
    let duration: TimeInterval
}

class HistoryService: ObservableObject {
    static let shared = HistoryService()
    
    @Published var items: [HistoryItem] = []
    
    private let saveKey = "history_items"
    
    private init() {
        loadHistory()
    }
    
    func addItem(transcript: String, duration: TimeInterval) {
        let newItem = HistoryItem(id: UUID(), date: Date(), transcript: transcript, duration: duration)
        items.insert(newItem, at: 0) // Newest first
        saveHistory()
    }
    
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveHistory()
    }
    
    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
}
