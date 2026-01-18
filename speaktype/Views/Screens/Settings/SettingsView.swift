import SwiftUI
import KeyboardShortcuts
import AVFoundation


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
    @AppStorage("customRecordingPath") private var customRecordingPath: String = ""
    
    @StateObject private var updateService = UpdateService.shared
    @State private var showUpdateSheet = false
    @State private var selectedHotkey = HotkeyOption.binding(forKey: "selectedHotkey", default: .fn)
    @StateObject private var audioRecorder = AudioRecordingService.shared
    
    // License Management
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showLicenseSheet = false
    @State private var showDeactivateAlert = false

    
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
                    
                    // Hotkey Selection Dropdown
                    HStack {
                        Text("Hotkey 1")
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: selectedHotkey) {
                            ForEach(HotkeyOption.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .labelsHidden()
                    }
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
                

                

                
                // Software Update Section
                SettingsSection {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.appRed)
                        VStack(alignment: .leading) {
                            Text("Software Update")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Keep your app up to date")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Current version info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Version")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("SpeakType \(AppVersion.currentVersion) (Build \(AppVersion.currentBuildNumber))")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await updateService.checkForUpdates()
                                if updateService.availableUpdate != nil {
                                    showUpdateSheet = true
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                if updateService.isCheckingForUpdates {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                }
                                Text(updateService.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(updateService.isCheckingForUpdates)
                    }
                    .padding(.vertical, 8)
                    
                    // Last check time
                    if let lastCheck = updateService.lastCheckDate {
                        Text("Last checked: \(lastCheck, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Auto-update toggle
                    ToggleRow(title: "Automatically check for updates", isOn: $autoUpdate)
                        .padding(.vertical, 4)
                    
                    Text("The app will check for updates every 24 hours and notify you when a new version is available.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                
                // License Section
                SettingsSection {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(Color.appRed)
                        Text("License")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Text("Manage your SpeakType Pro license")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // License Status
                    HStack {
                        Text("Status")
                            .foregroundStyle(.gray)
                        Spacer()
                        HStack(spacing: 6) {
                            if licenseManager.isPro {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Pro")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                Text("Free")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    
                    // Expiration Date (if applicable)
                    if let expirationDate = licenseManager.expirationDate {
                        Divider().background(Color.gray.opacity(0.3))
                        
                        HStack {
                            Text("Expires")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(expirationDate, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(licenseManager.isExpiringSoon ? .orange : .white)
                        }
                        .padding(.vertical, 4)
                        
                        if licenseManager.isExpiringSoon,
                           let days = licenseManager.daysUntilExpiration {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Expires in \(days) days")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Action Buttons
                    if licenseManager.isPro {
                        Button(action: {
                            showDeactivateAlert = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                Text("Deactivate License")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            showLicenseSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "key.fill")
                                Text("Activate License")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color.clear)
        .sheet(isPresented: $showUpdateSheet) {
            if let update = updateService.availableUpdate {
                UpdateSheet(update: update)
            }
        }
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
                .environmentObject(licenseManager)
        }
        .alert("Deactivate License", isPresented: $showDeactivateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Deactivate", role: .destructive) {
                Task {
                    try? await licenseManager.deactivateLicense()
                }
            }
        } message: {
            Text("Are you sure you want to deactivate your Pro license? You can reactivate it at any time.")
        }
        .onAppear {
            // Check if there's already an available update
            if updateService.availableUpdate != nil {
                showUpdateSheet = true
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
