import SwiftUI

struct MainView: View {
    @State private var selection: SidebarItem? = .dashboard
    @ObservedObject private var downloadService = ModelDownloadService.shared
    @AppStorage("hasShownModelPrompt") private var hasShownModelPrompt: Bool = false
    
    private var hasAnyModelDownloaded: Bool {
        downloadService.downloadProgress.values.contains { $0 >= 1.0 }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar - warmer background
            SidebarView(selection: $selection)
                .background(Color.bgSidebar)
            
            // Content area - white/light background
            ZStack {
                Color.bgContent
                    .ignoresSafeArea()
                
                contentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.bgSidebar)
        .onAppear {
            // If no model downloaded and haven't shown prompt, go to AI Models
            if !hasAnyModelDownloaded && !hasShownModelPrompt {
                hasShownModelPrompt = true
                selection = .aiModels
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .dashboard:
            DashboardView(selection: $selection)
        case .transcribeAudio:
            TranscribeAudioView()
        case .history:
            HistoryView()
        case .statistics:
            StatisticsView()
        case .aiModels:
            AIModelsView()
        case .settings:
            SettingsView()
        case .none:
            DashboardView(selection: $selection)
        }
    }
}
