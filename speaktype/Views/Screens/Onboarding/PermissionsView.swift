import SwiftUI
import AVFoundation


struct PermissionsView: View {
    @State private var micStatus: AVAuthorizationStatus = .notDetermined
    @State private var accessibilityStatus: Bool = false
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentPrimary)
                    
                    Text("App Permissions")
                        .font(Typography.displayLarge)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Manage permissions to ensure full functionality")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 32)
                
                // Permission Items
                VStack(spacing: 16) {
                    // Microphone
                    PermissionRow(
                        icon: "mic.fill",
                        color: .green,
                        title: "Microphone Access",
                        desc: "Allow SpeakType to record your voice for transcription",
                        isGranted: micStatus == .authorized,
                        action: { openSettings(for: "Privacy_Microphone") }
                    )
                    
                    // Accessibility
                    PermissionRow(
                        icon: "hand.raised.fill",
                        color: .green,
                        title: "Accessibility Access",
                        desc: "Allow SpeakType to paste transcribed text directly",
                        isGranted: accessibilityStatus,
                        action: { 
                            ClipboardService.shared.requestAccessibilityPermission()
                            // System dialog handles opening Settings when user clicks "Open System Settings"
                        }
                    )
                    

               }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .onAppear {
            checkPermissions()
            startPolling()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissions()
        }
    }
    
    func checkPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityStatus = AXIsProcessTrusted()
    }
    
    func openSettings(for pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(Color.textPrimary)
                Text(desc)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text("Manage")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            if isGranted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
        }
        .themedCard(padding: 20)
    }
}
