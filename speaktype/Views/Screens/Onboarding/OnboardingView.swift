import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - Match main app exactly
                Color.bgContent.ignoresSafeArea()
                
                // Content ZStack
                    ZStack {
                        if currentPage == 0 {
                            WelcomePage(action: {
                                withAnimation(.easeInOut(duration: 0.5)) { currentPage = 1 }
                            })
                            .transition(.opacity)
                        } else {
                            PermissionsPage(finishAction: {
                                completeOnboarding()
                            })
                            .transition(.opacity)
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 500) // Lower minimum size
        .frame(minWidth: 600, minHeight: 500) // Lower minimum size
    }
    
    func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

struct WelcomePage: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon / Hero with refined shadow
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 4)
            
            VStack(spacing: 16) {
                Text("Welcome to SpeakType")
                    .font(.system(size: 40, weight: .semibold, design: .default))
                    .foregroundStyle(Color.textPrimary)
                    .tracking(-0.5)
                
                Text("Experience the power of local AI transcription.\nSecure, fast, and completely offline.")
                    .font(.system(size: 15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: 480)
            }
            .padding(.top, 32)
            
            HStack(spacing: 20) {
                FeatureCard(icon: "lock.shield.fill", title: "Private by Design", description: "Your audio never leaves your device")
                FeatureCard(icon: "bolt.fill", title: "Lightning Fast", description: "Optimized for Apple Silicon")
                FeatureCard(icon: "keyboard.fill", title: "Works Everywhere", description: "Type with your voice in any app")
            }
            .padding(.top, 48)
            
            Spacer()
            
            Button(action: action) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 44)
                    .background(Color.accentPrimary)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
    }
}

struct PermissionsPage: View {
    var finishAction: () -> Void
    @State private var micStatus: AVAuthorizationStatus = .notDetermined
    @State private var accessibilityStatus: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Permissions Setup")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .tracking(-0.5)
                
                Text("SpeakType needs access to your microphone and accessibility features to function.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 480)
            }
            
            VStack(spacing: 12) {
                // Microphone
                OnboardingPermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Record your voice for transcription",
                    isGranted: micStatus == .authorized,
                    action: requestMicPermission
                )
                
                // Accessibility
                OnboardingPermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility Access",
                    description: "Type text into other apps",
                    isGranted: accessibilityStatus,
                    action: requestAccessibilityPermission
                )
            }
            .frame(maxWidth: 560)
            .padding(.top, 40)
            
            Spacer()
            
            Button(action: finishAction) {
                HStack(spacing: 8) {
                    Text("Start Using SpeakType")
                        .font(.system(size: 15, weight: .medium))
                    if micStatus == .authorized && accessibilityStatus {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 240, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((micStatus == .authorized && accessibilityStatus) ? Color.accentPrimary : Color.textMuted.opacity(0.3))
                )
                .shadow(color: (micStatus == .authorized && accessibilityStatus) ? Color.black.opacity(0.08) : Color.clear, radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(micStatus != .authorized || !accessibilityStatus)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear {
            checkPermissions()
            startPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            print("App became active, checking permissions...")
            checkPermissions()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // ... Copy-paste existing helpers (checkPermissions, request, polling) ...
    // Note: Re-implementing them inline for the tool call
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissions()
        }
    }
    
    func checkPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityStatus = AXIsProcessTrusted()
    }
    
    func requestMicPermission() {
        // Check current status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .authorized:
            // Already granted
            micStatus = .authorized
            return
            
        case .notDetermined:
            // Show native permission prompt
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.checkPermissions()
                }
            }
            
        case .denied, .restricted:
            // User previously denied - open System Settings
            openSettings(for: "Privacy_Microphone")
            
        @unknown default:
            break
        }
    }
    
    func requestAccessibilityPermission() {
        print("DEBUG: Requesting Accessibility Permission")
        
        // First check current status
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus {
            // Already granted
            accessibilityStatus = true
            return
        }
        
        // Show the native macOS prompt (will appear automatically)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        accessibilityStatus = accessEnabled
        
        // Note: We don't manually open System Settings here because
        // the native prompt will show. Only open manually if user
        // needs to re-enable after denying (handled by polling)
    }
    
    func openSettings(for pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon with premium styling
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.bgHover)
                )
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .tracking(-0.2)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 180, height: 180)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.border.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
    }
}

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 18) {
            // Icon with refined styling
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.bgHover)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .tracking(-0.2)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Granted")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.accentSuccess)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentSuccess.opacity(0.08))
                )
            } else {
                Button(action: action) {
                    Text("Allow Access")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.accentPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isGranted ? Color.accentSuccess.opacity(0.15) : Color.border.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
    }
}

#Preview {
    OnboardingView()
}
