import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @State private var selectedItem: HistoryItem?
    
    var body: some View {
        NavigationSplitView {
            List(historyService.items, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.transcript.prefix(50) + (item.transcript.count > 50 ? "..." : ""))
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text(formatDuration(item.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            historyService.deleteItem(id: item.id)
                            if selectedItem?.id == item.id {
                                selectedItem = nil
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .listStyle(.sidebar)
        } detail: {
            if let item = selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text(item.date.formatted(date: .long, time: .standard))
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            
                            Spacer()
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.transcript, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        
                        Divider()
                        
                        Text(item.transcript)
                            .font(.body)
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                        
                        Spacer()
                    }
                    .padding(30)
                }
                .background(Color.contentBackground)
            } else {
                Text("Select a recording to view transcript")
                    .foregroundStyle(.gray)
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
