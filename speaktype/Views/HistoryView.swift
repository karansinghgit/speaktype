import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @State private var selectedItem: HistoryItem?
    @State private var showCopyAlert = false
    
    var body: some View {
        NavigationSplitView {
            List(historyService.items, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.transcript.prefix(50) + (item.transcript.count > 50 ? "..." : ""))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text(formatDuration(item.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        Text(item.date.formatted(date: .long, time: .standard))
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.transcript, forType: .string)
                            showCopyAlert = true
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .alert("Text Copied", isPresented: $showCopyAlert) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("Transcript has been copied to clipboard.")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    // Edge-to-Edge Transcript
                    ScrollView {
                        Text(item.transcript)
                            .font(.body)
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.contentBackground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
