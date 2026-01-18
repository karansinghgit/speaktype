import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo Header
            HStack(spacing: 12) {
                Image("AppLogo") // Corrected asset name
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48) // Slightly larger logo
                
                Text("SpeakType")
                    .font(.system(size: 22, weight: .bold)) // Reduced text size
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 40) // Space for traffic lights
            .padding(.bottom, 30)
            
            VStack(spacing: 6) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarButton(
                        item: item,
                        isSelected: selection == item,
                        action: { selection = item }
                    )
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .frame(width: 260)
        .background(Color.clear)
    }
}

struct SidebarButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.title3) // Keep icon size consistent or slightly larger
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Color(hex: "E5E5E7"))
                    .frame(width: 24)
                
                Text(item.rawValue)
                    .font(.title3) // Even bigger tab text (was .headline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? .white : Color(hex: "E5E5E7"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected ? 
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(hex: "A62D35"), Color(hex: "2D5DA6")], // Red to Blue gradient matching reference
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) : AnyShapeStyle(Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Enum definition needs to be here if it was in the deleted file, 
// otherwise if it was in MainView.swift or another file, I shouldn't duplicate it.
// Checking previous steps, SidebarItem was in SidebarView.swift. So I must include it.

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case aiModels = "AI Models"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "circle.grid.2x2"
        case .transcribeAudio: return "waveform"
        case .history: return "doc.text"
        case .aiModels: return "cpu"
        case .permissions: return "shield"
        case .audioInput: return "mic"
        case .settings: return "gearshape"
        }
    }
}
