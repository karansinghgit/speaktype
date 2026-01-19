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
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
 
    @AppStorage("autoUpdate") private var autoUpdate = true
    @AppStorage("showAnnouncements") private var showAnnouncements = true
    @AppStorage("customCancelShortcut") private var customCancelShortcut = false
    @AppStorage("middleClickToggle") private var middleClickToggle = false
    @AppStorage("appleScriptPaste") private var appleScriptPaste = false
    @AppStorage("recorderStyle") private var recorderStyle: Int = 1 // 0: Notch, 1: Mini
    // hotkey1 removed as it was unused and confusing
    @AppStorage("selectedHotkey") private var selectedHotkey: HotkeyOption = .fn
    @AppStorage("customRecordingPath") private var customRecordingPath: String = ""
    
    @StateObject private var updateService = UpdateService.shared
    @State private var showUpdateSheet = false
    // selectedHotkey moved to AppStorage
    @StateObject private var audioRecorder = AudioRecordingService.shared
    
    // License Management
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showLicenseSheet = false
    @State private var showDeactivateAlert = false

    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Appearance Section
                SettingsSection {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(Color.appRed)
                        Text("Appearance")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Text("Choose your preferred theme")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    
                    Divider().background(Color.borderSubtle)
                    
                    HStack(spacing: 20) {
                        ForEach(AppTheme.allCases) { theme in
                            RadioButton(
                                title: theme.rawValue,
                                isSelected: appTheme == theme,
                                action: {
                                    withAnimation(.easeInOut) {
                                        appTheme = theme
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Shortcuts Section
                SettingsSection {
                    HStack {
                        Image(systemName: "command.circle")
                            .foregroundStyle(Color.appRed)
                        Text("SpeakType Shortcuts")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
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
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Menu {
                            ForEach(HotkeyOption.allCases) { option in
                                Button(option.displayName) {
                                    selectedHotkey = option
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedHotkey.displayName)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.bgCard)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 140)
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
                        .foregroundStyle(Color.textSecondary)
                }
                

                

                
                // Software Update Section
                SettingsSection {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.appRed)
                        VStack(alignment: .leading) {
                            Text("Software Update")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                            Text("Keep your app up to date")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
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
                                .foregroundStyle(Color.textSecondary)
                            Text("SpeakType \(AppVersion.currentVersion) (Build \(AppVersion.currentBuildNumber))")
                                .font(.subheadline)
                                .foregroundStyle(Color.textPrimary)
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
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Text("Manage your SpeakType Pro license")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    
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
                                    .foregroundStyle(Color.textPrimary)
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
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text(expirationDate, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(licenseManager.isExpiringSoon ? .orange : Color.textPrimary)
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
        .background(Color.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderCard, lineWidth: 1)
        )
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bgHover)
                .cornerRadius(4)
                .foregroundStyle(Color.textPrimary)
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.textPrimary)
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
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { rawValue }
}
