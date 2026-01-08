import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    private var miniRecorderController: MiniRecorderWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the controller
        miniRecorderController = MiniRecorderWindowController()
        
        // Setup global hotkey listener
        KeyboardShortcuts.onKeyUp(for: .toggleRecord) { [weak self] in
            // Direct toggle via controller. 
            // Bypasses URL schemes and SwiftUI Scene routing completely.
            self?.miniRecorderController?.toggle()
        }
    }
    
    // Critical: Prevent the app from quitting when the Mini Recorder panel closes.
    // Since we are a Menu Bar app (mostly), we must stay alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
