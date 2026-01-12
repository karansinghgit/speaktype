
import Cocoa
import SwiftUI

class MiniRecorderWindowController: NSObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    
    // Toggle visibility
    func toggle() {
        if panel == nil {
            setupPanel()
        }
        
        guard let panel = panel else { return }
        
        if panel.isVisible {
            print("Hiding Mini Recorder Panel")
            panel.orderOut(nil)
        } else {
            print("Showing Mini Recorder Panel")
            panel.center()
            
            // Show without activating to avoid pulling main app focus unnecessarily
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            
            // Trigger instant recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .hotkeyTriggered, object: nil)
            }
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
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
        p.hasShadow = false // Remove shadow to kill "boundary" artifact
        
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
            
            // 2. Hide window to return focus
            await MainActor.run {
                 print("Closing recorder panel...")
                 self.panel?.orderOut(nil)
                 // Also force deactivation just in case
                 NSApp.hide(nil)
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
