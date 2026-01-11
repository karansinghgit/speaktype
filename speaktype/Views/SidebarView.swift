import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case aiModels = "AI Models"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .dashboard: return "gauge"
        case .transcribeAudio: return "waveform"
        case .history: return "doc.text"
        case .aiModels: return "brain.head.profile"
        case .permissions: return "shield"
        case .audioInput: return "mic"
        case .settings: return "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(selection: $selection) {
            // Header removed for clean design
            
            Section {
                ForEach(SidebarItem.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.iconName)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .preferredColorScheme(.dark)
    }
}
