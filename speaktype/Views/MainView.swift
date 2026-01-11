import SwiftUI

struct MainView: View {
    @State private var selection: SidebarItem? = .dashboard
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView(selection: $selection)
            case .transcribeAudio:
                TranscribeAudioView()
            case .history:
                HistoryView()
            case .aiModels:
                AIModelsView()
            case .permissions:
                PermissionsView()
            case .audioInput:
                AudioInputView()
            case .settings:
                SettingsView()
            default:
                Text("Content for \(selection?.rawValue ?? "Selection") coming soon")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.contentBackground)
                    .foregroundStyle(.white)
            }
        }
        // .navigationTitle("SpeakType") // Removed for clean look
        .fontDesign(.rounded) // Global modern font design
    }
}
