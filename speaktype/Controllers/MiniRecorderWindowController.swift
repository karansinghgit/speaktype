
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
            // Center closely to mouse or screen center? Center of screen is safer.
            // But let's respect previous floating behavior.
            panel.center() 
            // panel.makeKeyAndOrderFront(nil) -> Activates app. We want specific behavior.
            // We want it to float but NOT activate the app if possible?
            // Actually, for a recorder, we usually want it visible.
            
            // To prevent activating the Main App (and thus showing Main Dashboard if it was key),
            // we show the panel without activating the app?
            // "panel.orderFront(nil)" shows it.
            
            // However, to type into it (if needed) or interact, we might need activation.
            // But our Mini Recorder is button-based.
            
            // Critical: If we use NSApp.activate, it might switch to the main dashboard scene if that's "primary".
            // By managing this panel separately, we avoid SwiftUI triggering the main scene.
            
            // orderFrontRegardless allows showing the window without activating the app
            panel.orderFrontRegardless()
            // panel.orderFrontDuringApplicationMakeKey() // Does not exist
            // panel.makeKeyAndOrderFront(nil)
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
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0s wait for stability
            
            // 4. Robust Paste Routine
            print("Attempting Paste Routine...")
            
            // Check permission just for logging, but try anyway
            if !ClipboardService.shared.isAccessibilityTrusted {
                 print("⚠️ Accessibility might be missing, but proceeding with force paste.")
            }
            
            // Method A: CGEvent (Fast)
            ClipboardService.shared.paste()
            
            // Method B: AppleScript (Robust backup for 'previous app' context)
            // Small delay to let CGEvent fire first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            await MainActor.run {
                ClipboardService.shared.appleScriptPaste()
            }
        }
    }
}
