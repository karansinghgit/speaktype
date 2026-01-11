import SwiftUI
import KeyboardShortcuts


// import LaunchAtLogin // Uncomment when package added
// import KeyboardShortcuts // Uncomment when package added

struct SettingsView: View {
    @AppStorage("soundFeedback") private var soundFeedback = true
    @AppStorage("muteSystemAudio") private var muteSystemAudio = true
    @AppStorage("restoreClipboard") private var restoreClipboard = false
    @AppStorage("powerMode") private var powerMode = false
    @AppStorage("experimentalFeatures") private var experimentalFeatures = false
    @AppStorage("hideDockIcon") private var hideDockIcon = false
 
    @AppStorage("autoUpdate") private var autoUpdate = true
    @AppStorage("showAnnouncements") private var showAnnouncements = true
    @AppStorage("customCancelShortcut") private var customCancelShortcut = false
    @AppStorage("middleClickToggle") private var middleClickToggle = false
    @AppStorage("appleScriptPaste") private var appleScriptPaste = false
    @AppStorage("recorderStyle") private var recorderStyle: Int = 1 // 0: Notch, 1: Mini
    @AppStorage("hotkey1") private var hotkey1: String = "⌘ Space"
    @AppStorage("useFnKey") private var useFnKey = true
    @AppStorage("customRecordingPath") private var customRecordingPath: String = ""

    
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
                    
                    // Fn Key Toggle
                    ToggleRow(title: "Use Function (fn) Key", isOn: $useFnKey)
                        .padding(.vertical, 4)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Custom Shortcut
                    HStack {
                        Text("Custom Shortcut")
                            .foregroundStyle(.gray)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecord)
                    }
                    .padding(.vertical, 8)
                    
                    Text("Quick tap to start hands-free recording (tap again to stop). Press and hold for push-to-talk.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                

                
                // Storage
                SettingsSection {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundStyle(Color.appRed)
                        VStack(alignment: .leading) {
                            Text("Storage")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Where recordings are saved")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(customRecordingPath.isEmpty ? "Default (Documents)" : customRecordingPath)
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                        
                        HStack {
                            if !customRecordingPath.isEmpty {
                                Button("Reset to Default") {
                                    customRecordingPath = ""
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            Button("Change Location") {
                                selectFolder()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.contentBackground)
    }

    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                customRecordingPath = url.path
            }
        }
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
