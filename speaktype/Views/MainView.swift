import SwiftUI

struct MainView: View {
    @State private var selection: SidebarItem? = .dashboard
    
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
