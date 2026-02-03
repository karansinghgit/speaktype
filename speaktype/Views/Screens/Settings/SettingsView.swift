import SwiftUI
import KeyboardShortcuts
import AVFoundation

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(Typography.displayLarge)
                    .foregroundStyle(Color.textPrimary)
                
                // Tab bar
                HStack(spacing: 0) {
                    ForEach(SettingsTab.allCases) { tab in
                        SettingsTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Tab content
            switch selectedTab {
            case .general:
                GeneralSettingsTab()
            case .audio:
                AudioSettingsTab()
            case .permissions:
                PermissionsSettingsTab()
            }
        }
        .background(Color.clear)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case permissions = "Permissions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "mic"
        case .permissions: return "shield"
        }
    }
}

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                Text(tab.rawValue)
                    .font(Typography.bodyMedium)
            }
            .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.bgHover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("autoUpdate") private var autoUpdate = true
    @AppStorage("selectedHotkey") private var selectedHotkey: HotkeyOption = .fn
    
    @StateObject private var updateService = UpdateService.shared
    @EnvironmentObject var licenseManager: LicenseManager
    
    @State private var showUpdateSheet = false
    @State private var showLicenseSheet = false
    @State private var showDeactivateAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Appearance
                SettingsSection {
                    SettingsSectionHeader(icon: "paintpalette", title: "Appearance", subtitle: "Choose your preferred theme")
                    
                    HStack(spacing: 20) {
                        ForEach(AppTheme.allCases) { theme in
                            RadioButton(
                                title: theme.rawValue,
                                isSelected: appTheme == theme,
                                action: { appTheme = theme }
                            )
                        }
                    }
                }
                
                // Shortcuts
                SettingsSection {
                    SettingsSectionHeader(icon: "command", title: "Shortcuts", subtitle: "Configure recording hotkeys")
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Primary Hotkey")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Menu {
                                ForEach(HotkeyOption.allCases) { option in
                                    Button(option.displayName) {
                                        selectedHotkey = option
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(selectedHotkey.displayName)
                                        .font(Typography.bodySmall)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.bgHover)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .menuStyle(.borderlessButton)
                        }
                        
                        Divider()
                            .background(Color.border.opacity(0.5))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Custom Shortcut")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                KeyboardShortcuts.Recorder(for: .toggleRecord)
                            }
                            
                            Text("Quick tap to start hands-free recording. Press and hold for push-to-talk.")
                                .font(Typography.captionSmall)
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                }
                
                // Updates
                SettingsSection {
                    SettingsSectionHeader(icon: "arrow.down.circle", title: "Updates", subtitle: "SpeakType \(AppVersion.currentVersion)")
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Automatically check for updates")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Toggle("", isOn: $autoUpdate)
                                .labelsHidden()
                        }
                        
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
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                }
                                Text(updateService.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                                    .font(Typography.labelMedium)
                            }
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(updateService.isCheckingForUpdates)
                    }
                }
                
                // License - Hidden (logic kept for future use)
                // SettingsSection {
                //     SettingsSectionHeader(
                //         icon: "key",
                //         title: "License",
                //         subtitle: licenseManager.isPro ? "Pro Active" : "Free Plan"
                //     )
                //     
                //     if licenseManager.isPro {
                //         Button(action: { showDeactivateAlert = true }) {
                //             Text("Deactivate License")
                //                 .font(Typography.labelMedium)
                //                 .frame(maxWidth: .infinity)
                //         }
                //         .buttonStyle(.stSecondary)
                //     } else {
                //         Button(action: { showLicenseSheet = true }) {
                //             Text("Activate License")
                //                 .font(Typography.labelMedium)
                //                 .frame(maxWidth: .infinity)
                //         }
                //         .buttonStyle(.stPrimary)
                //     }
                // }
            }
            .padding(24)
        }
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
                Task { try? await licenseManager.deactivateLicense() }
            }
        } message: {
            Text("Are you sure you want to deactivate your Pro license?")
        }
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    @StateObject private var audioRecorder = AudioRecordingService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection {
                    SettingsSectionHeader(icon: "mic", title: "Input Device", subtitle: "Select your microphone")
                    
                    VStack(spacing: 12) {
                        if audioRecorder.availableDevices.isEmpty {
                            Text("No input devices found")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Color.textMuted)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(audioRecorder.availableDevices, id: \.uniqueID) { device in
                                DeviceRow(
                                    name: device.localizedName,
                                    isActive: audioRecorder.selectedDeviceId == device.uniqueID,
                                    isSelected: audioRecorder.selectedDeviceId == device.uniqueID
                                )
                                .onTapGesture {
                                    audioRecorder.selectedDeviceId = device.uniqueID
                                }
                            }
                        }
                    }
                    
                    Button(action: { audioRecorder.fetchAvailableDevices() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Refresh Devices")
                                .font(Typography.labelMedium)
                        }
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.bgHover)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
        .onAppear {
            audioRecorder.fetchAvailableDevices()
        }
    }
}

// MARK: - Permissions Settings Tab

struct PermissionsSettingsTab: View {
    @State private var micStatus: AVAuthorizationStatus = .notDetermined
    @State private var accessibilityStatus: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection {
                    SettingsSectionHeader(icon: "shield", title: "App Permissions", subtitle: "Required for full functionality")
                    
                    VStack(spacing: 10) {
                        SettingsPermissionItem(
                            icon: "mic.fill",
                            color: Color.textSecondary,
                            title: "Microphone Access",
                            desc: "Record your voice for transcription",
                            isGranted: micStatus == .authorized,
                            action: { openSettings(for: "Privacy_Microphone") }
                        )
                        
                        SettingsPermissionItem(
                            icon: "hand.raised.fill",
                            color: Color.textSecondary,
                            title: "Accessibility Access",
                            desc: "Paste transcribed text directly",
                            isGranted: accessibilityStatus,
                            action: {
                                ClipboardService.shared.requestAccessibilityPermission()
                                // System dialog handles opening Settings when user clicks "Open System Settings"
                            }
                        )
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            checkPermissions()
            startPolling()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityStatus = AXIsProcessTrusted()
    }
    
    private func openSettings(for pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Supporting Components

struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.labelLarge)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
            }
            
            Spacer()
        }
        .padding(.bottom, 16)
    }
}

struct SettingsSection<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .themedCard(padding: 24)
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(Typography.bodyMedium)
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
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentPrimary : Color.textMuted, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsPermissionItem: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.textMuted)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color.bgHover)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(desc)
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.textSecondary)
                    .font(.system(size: 20))
            } else {
                Button("Enable") {
                    action()
                }
                .font(Typography.labelSmall)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { rawValue }
}
