import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @State private var showCopyAlert = false
    @State private var showDeleteAlert = false
    
    // We don't need selectedItem anymore for a simple list
    // We can track which item gets copied to show the alert using a simpler mechanism or just the bool
    
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
                        DisclosureGroup {
                            // Expanded Content
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()
                                
                                Text(item.transcript)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true) // Allow multiline growth
                                
                                Button(action: {
                                    copyToClipboard(text: item.transcript)
                                }) {
                                    Label("Copy Transcript", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                        } label: {
                            // Collapsed Header
                            HStack {
                                VStack(alignment: .leading) {
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

        .alert("Copied", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Transcript copied to clipboard.")
        }
    }
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopyAlert = true
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
