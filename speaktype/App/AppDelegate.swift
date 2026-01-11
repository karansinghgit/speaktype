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
        
        // Fn Key Monitor (KeyCode 63)
         NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
             if event.keyCode == 63 {
                 // Check if pressed (modifier flags contain .function)
                 // Note: This triggers on both press and release if we don't check flags carefully
                 // For toggle, we usually want "on press"
                 if event.modifierFlags.contains(.function) {
                     self?.miniRecorderController?.toggle()
                 }
             }
         }
         
         NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
             let useFnKey = UserDefaults.standard.object(forKey: "useFnKey") as? Bool ?? true
             if useFnKey && event.keyCode == 63 && event.modifierFlags.contains(.function) {
                 self?.miniRecorderController?.toggle()
             }
             return event
         }
        
        // Start Hidden: Close the main window that SwiftUI opens by default
        // UNLESS we are in UI testing mode
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        if !isUITesting {
            DispatchQueue.main.async {
                NSApplication.shared.windows.forEach { window in
                    window.close()
                }
            }
        }
    }
    
    // Critical: Prevent the app from quitting when the Mini Recorder panel closes.
    // Since we are a Menu Bar app (mostly), we must stay alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
