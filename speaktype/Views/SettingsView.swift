import SwiftUI
import KeyboardShortcuts

// import LaunchAtLogin // Uncomment when package added
// import KeyboardShortcuts // Uncomment when package added

struct SettingsView: View {
    @State private var soundFeedback = true
    @State private var muteSystemAudio = true
    @State private var restoreClipboard = false
    @State private var powerMode = false
    @State private var experimentalFeatures = false
    @State private var hideDockIcon = false
    @State private var launchAtLogin = false // Will be replaced by LaunchAtLogin.isEnabled if package used
    @State private var autoUpdate = true
    @State private var showAnnouncements = true
    @State private var customCancelShortcut = false
    @State private var middleClickToggle = false
    @State private var appleScriptPaste = false
    @State private var recorderStyle: Int = 1 // 0: Notch, 1: Mini
    @State private var hotkey1: String = "⌘ Space"

    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Shortcuts Section
                SettingsSection {
                    HStack {
                        Image(systemName: "command.circle")
                            .foregroundStyle(Color.appRed)
                        Text("SpeakType Shortcuts")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Text("Choose how you want to trigger SpeakType")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    HStack {
                        Text("Global Hotkey")
                            .foregroundStyle(.gray)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecord)
                    }
                    .padding(.vertical, 8)
                    
                    Text("Quick tap to start hands-free recording (tap again to stop). Press and hold for push-to-talk.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                
                // General
                SettingsSection {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundStyle(Color.appRed)
                        VStack(alignment: .leading) {
                            Text("General")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Startup settings")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    
                    ToggleRow(title: "Launch at login", isOn: $launchAtLogin)
                    // Note: If using LaunchAtLogin package, replace the above line with:
                    // LaunchAtLogin.Toggle {
                    //    Text("Launch at login")
                    // }
                }
            }
            .padding()
        }
        .background(Color.contentBackground)
    }
}

struct SettingsSection<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .foregroundStyle(.white)
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.appRed : .gray)
                Text(title)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
