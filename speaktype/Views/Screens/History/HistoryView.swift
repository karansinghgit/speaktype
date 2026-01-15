import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            Text("History")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            if historyService.items.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Your transcriptions will appear here.")
                )
            } else {
                List {
                    ForEach(historyService.items) { item in
                        NavigationLink(destination: HistoryDetailView(item: item)) {
                            // Row Content
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Text(item.transcript.prefix(60) + (item.transcript.count > 60 ? "..." : ""))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(formatDuration(item.duration))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.inset)
                }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !historyService.items.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Clear History", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
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
    
    private func deleteItems(at offsets: IndexSet) {
        historyService.deleteItem(at: offsets)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
