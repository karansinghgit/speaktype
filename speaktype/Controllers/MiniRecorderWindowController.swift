
import Cocoa
import SwiftUI

class MiniRecorderWindowController: NSObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<MiniRecorderView>?
    
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
        
        hostingController = NSHostingController(rootView: recorderView)
        
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .hudWindow], 
            backing: .buffered,
            defer: false
        )
        
        p.contentViewController = hostingController
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        
        // Window Behavior
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false // Keep floating even if focus lost? Yes.
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
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            
            // 4. Paste
            if ClipboardService.shared.isAccessibilityTrusted {
                print("Simulating Paste (Accessibility Trusted)...")
                ClipboardService.shared.paste()
                print("Paste command sent.")
            } else {
                print("⚠️ Accessibility Permission Missing! Cannot paste. Requesting system prompt...")
                // Trigger native system prompt which is more reliable for re-association
                await MainActor.run {
                     ClipboardService.shared.requestAccessibilityPermission()
                }
            }
        }
    }
}
