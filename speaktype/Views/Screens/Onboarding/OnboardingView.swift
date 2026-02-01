import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - Darker Contrast (Matches Main App)
                ZStack {
                    Color.bgApp.ignoresSafeArea()
                    
                    // Subtle ambient gradient for premium feel
                    LinearGradient(
                        colors: [Color.accentRed.opacity(0.15), Color.accentBlue.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                
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
        VStack(spacing: 40) {
            // Icon / Hero
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 16) {
                Text("Welcome to SpeakType")
                    .font(Typography.displayLarge)
                    .foregroundStyle(Color.textPrimary)
                
                Text("Experience the power of local AI transcription. Secure, fast, and completely offline.")
                    .font(Typography.bodyLarge)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: 500)
            }
            
            HStack(spacing: 24) {
                FeatureCard(icon: "lock.shield.fill", title: "Private by Design", description: "Your audio never leaves your device.")
                FeatureCard(icon: "bolt.fill", title: "Lightning Fast", description: "Optimized for Apple Silicon.")
                FeatureCard(icon: "keyboard.fill", title: "Global Injection", description: "Type with your voice anywhere.")
            }
            
            Button(action: action) {
                Text("Get Started")
                    .font(Typography.labelLarge)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(Color.accentRed)
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
        }
    }
}

struct PermissionsPage: View {
    var finishAction: () -> Void
    @State private var micStatus: AVAuthorizationStatus = .notDetermined
    @State private var accessibilityStatus: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 10) {
                Text("Permissions Setup")
                    .font(Typography.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                Text("SpeakType needs access to your microphone and accessibility features to function.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            VStack(spacing: 20) {
                // Microphone
                OnboardingPermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice.",
                    isGranted: micStatus == .authorized,
                    action: requestMicPermission
                )
                
                // Accessibility
                OnboardingPermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required to type text into other apps.",
                    isGranted: accessibilityStatus,
                    action: requestAccessibilityPermission
                )
            }
            .frame(maxWidth: 600) // Readability constraint
            
            Spacer()
            
            Button(action: finishAction) {
                HStack {
                    Text("Start Using SpeakType")
                        .font(Typography.labelLarge)
                    if micStatus == .authorized && accessibilityStatus {
                        Image(systemName: "checkmark")
                    }
                }
                .foregroundColor(.white)
                .frame(width: 300, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill((micStatus == .authorized && accessibilityStatus) ? Color.accentRed : Color.gray.opacity(0.3))
                        .shadow(color: (micStatus == .authorized && accessibilityStatus) ? Color.accentRed.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
                )
                .animation(.easeInOut, value: micStatus == .authorized && accessibilityStatus)
            }
            .buttonStyle(.plain)
            .disabled(micStatus != .authorized || !accessibilityStatus)
            .padding(.bottom, 40)
        }
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
        Task.detached(priority: .userInitiated) {
            let mic = AVCaptureDevice.authorizationStatus(for: .audio)
            let access = AXIsProcessTrusted()
            
            await MainActor.run {
                self.micStatus = mic
                self.accessibilityStatus = access
            }
        }
    }
    
    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            DispatchQueue.main.async { checkPermissions() }
        }
        // Also open settings if denied?
         if micStatus == .denied {
            openSettings(for: "Privacy_Microphone")
         }
    }
    
    func requestAccessibilityPermission() {
        print("DEBUG: Requesting Accessibility Permission")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        accessibilityStatus = accessEnabled
        
        if !accessEnabled {
             print("DEBUG: Access not enabled, opening settings")
             openSettings(for: "Privacy_Accessibility")
        }
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
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Color.accentRed)
                .frame(width: 50, height: 50)
                .background(Color.accentRed.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(Typography.labelMedium)
                .foregroundStyle(Color.textPrimary)
            
            Text(description)
                .font(Typography.captionSmall)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 140, height: 160)
        .padding()
        .padding()
        .background(Color.bgCard)
        .cornerRadius(20)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.borderCard, lineWidth: 1)
        )
    }
}

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentRed)
                .frame(width: 50, height: 50)
                .background(Color.accentRed.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(description)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            if isGranted {
                HStack {
                    Text("Granted")
                        .font(Typography.labelMedium)
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                Button(action: action) {
                    Text("Allow Access")
                        .font(Typography.labelMedium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentRed)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .padding(20)
        .background(Color.bgCard)
        .cornerRadius(16)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.borderCard, lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView()
}
