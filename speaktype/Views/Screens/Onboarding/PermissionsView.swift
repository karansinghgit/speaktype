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
                VStack(spacing: 15) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appRed)
                    
                    Text("App Permissions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Manage permissions to ensure full functionality")
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 40)
                
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
                            // Also open settings in case prompt doesn't appear (e.g. already denied)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                openSettings(for: "Privacy_Accessibility")
                            }
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
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button("Manage") {
                action()
            }
            .buttonStyle(.bordered)
            .tint(Color.gray)
            
            if isGranted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderCard, lineWidth: 1)
        )
    }
}
