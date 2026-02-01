
import Cocoa
import SwiftUI

class MiniRecorderWindowController: NSObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var lastActiveApp: NSRunningApplication?
    
    // Start recording - show panel and begin recording
    func startRecording() {
        // Capture previous app to restore focus later
        lastActiveApp = NSWorkspace.shared.frontmostApplication
        
        if panel == nil {
            setupPanel()
        }
        
        guard let panel = panel else { return }
        
        if !panel.isVisible {
            print("Showing Mini Recorder Panel")
            
            // Force layout to ensure frame is correct
            panel.layoutIfNeeded()
            
            // Position above dock with fixed width (panel width should be 220)
            if let screen = NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let windowWidth: CGFloat = 220 // Fixed width from setupPanel
                let x = visibleFrame.midX - (windowWidth / 2)
                let y = visibleFrame.minY + 50 // 50px padding above dock
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                panel.center()
            }
            
            // Show without activating to avoid pulling main app focus unnecessarily
            panel.orderFrontRegardless()
        }
        
        // Trigger instant recording
        NotificationCenter.default.post(name: .recordingStartRequested, object: nil)
    }
    
    // Stop recording - trigger transcription and paste
    func stopRecording() {
        // 1. Hide recorder immediately - REMOVED so it shows "Transcribing..."
        // panel?.orderOut(nil)
        
        // 2. Return focus to previous app
        _ = lastActiveApp?.activate(options: [])
        
        // 3. Trigger transcription
        NotificationCenter.default.post(name: .recordingStopRequested, object: nil)
    }
    
    private func setupPanel() {
        // Initialize View with callbacks
        let recorderView = MiniRecorderView(
            onCommit: { [weak self] text in
                self?.handleCommit(text: text)
            },
            onCancel: { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        
        // Initialize hosting controller with transparent background view
        // Wrap in AnyView because .background() changes the type from MiniRecorderView to some View
        hostingController = NSHostingController(rootView: AnyView(recorderView.background(Color.clear)))
        
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 50),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        p.isOpaque = false
        p.backgroundColor = .clear
        
        p.contentViewController = hostingController
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.hasShadow = false // Disable system shadow to avoid transparency artifacts (View has its own shadow)
        
        // Window Behavior
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false // Keep floating even if focus lost
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.panel = p
    }
    
    private func handleCommit(text: String) {
        Task {
            // 1. Copy to clipboard
            ClipboardService.shared.copy(text: text)
            
            // 2. Close panel
            await MainActor.run {
                self.panel?.orderOut(nil)
            }
            
            // 3. Check accessibility and show alert if needed
            let accessibilityTrusted = ClipboardService.shared.isAccessibilityTrusted
            
            if !accessibilityTrusted {
                await MainActor.run {
                    self.showAccessibilityAlert()
                }
                return
            }
            
            // 4. Re-activate the target app
            if let app = self.lastActiveApp {
                await MainActor.run {
                    _ = app.activate(options: [])
                }
            }
            
            // 5. Wait for focus
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 6. Paste using CGEvent (Accessibility permission only)
            await MainActor.run {
                ClipboardService.shared.paste()
            }
        }
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "SpeakType needs Accessibility permission to automatically paste transcriptions into the active app.\n\nYour transcription has been copied to the clipboard.\n\nTo enable auto-paste, grant permission in:\nSystem Settings → Privacy & Security → Accessibility"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
