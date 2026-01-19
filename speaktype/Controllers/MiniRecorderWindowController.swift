
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
            
            // Position above dock
            if let screen = NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let windowWidth = panel.frame.width
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
        lastActiveApp?.activate(options: .activateIgnoringOtherApps)
        
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
            
            // 2. Ensure panel is closed
            await MainActor.run {
                 self.panel?.orderOut(nil)
            }
            
            // 3. Wait for focus switch
            print("Waiting for focus switch...")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s wait for stability
            
            // 4. Robust Paste Routine
            print("Attempting Paste Routine...")
            
            if ClipboardService.shared.isAccessibilityTrusted {
                // User has permissions, but CGEvent is failing for them.
                // Switch to AppleScript (System Events) as PRIMARY method. It's slower but 100% reliable.
                print("✅ Accessibility Trusted. Using robust AppleScript paste.")
                
                // Small delay to ensure 'System Events' is ready
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                await MainActor.run {
                    ClipboardService.shared.appleScriptPaste()
                }
            } else {
                // No permissions? Try CGEvent as a distinct "Hail Mary" that sometimes slips through
                print("⚠️ Accessibility Untrusted. Trying CGEvent fallback.")
                ClipboardService.shared.paste()
            }
        }
    }
}
