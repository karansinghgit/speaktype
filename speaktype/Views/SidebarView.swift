import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo Header
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                
                Text("SpeakType")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                
                // Badge like Flow's "Basic"
                Text("Pro")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // Navigation - no divider, seamless
            VStack(spacing: 2) {
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
            
            // Bottom section like Flow
            VStack(spacing: 0) {
                // Upgrade prompt
                VStack(alignment: .leading, spacing: 6) {
                    Text("Try SpeakType Pro")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Unlimited transcriptions")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                    
                    Button(action: {}) {
                        Text("Upgrade")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.border, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                
                // Bottom links
                VStack(spacing: 0) {
                    SidebarBottomLink(icon: "gearshape", title: "Settings")
                    SidebarBottomLink(icon: "questionmark.circle", title: "Help")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 220)
        .background(Color.bgSidebar)
        // No border - seamless with content
    }
}

struct SidebarButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.sidebarItem)
                    .frame(width: 22)
                
                Text(item.rawValue)
                    .font(Typography.sidebarItem)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.sidebarItem)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected 
                            ? Color.bgSelected
                            : (isHovered ? Color.bgHover : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SidebarBottomLink: View {
    let icon: String
    let title: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.sidebarItem)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.sidebarItem)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.bgHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Enum definition needs to be here if it was in the deleted file, 
// otherwise if it was in MainView.swift or another file, I shouldn't duplicate it.
// Checking previous steps, SidebarItem was in SidebarView.swift. So I must include it.

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case statistics = "Statistics"
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
        case .statistics: return "chart.bar.fill"
        case .aiModels: return "cpu"
        case .permissions: return "shield"
        case .audioInput: return "mic"
        case .settings: return "gearshape"
        }
    }
}
