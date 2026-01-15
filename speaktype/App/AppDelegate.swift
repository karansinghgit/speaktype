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
        
        // Check for updates on app launch
        checkForUpdatesOnLaunch()
        
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
    
    // MARK: - Update Checking
    
    private func checkForUpdatesOnLaunch() {
        let updateService = UpdateService.shared
        let autoUpdate = UserDefaults.standard.bool(forKey: "autoUpdate")
        
        // Only check if auto-update is enabled and enough time has passed
        guard autoUpdate && updateService.shouldCheckForUpdates() else { return }
        
        Task {
            await updateService.checkForUpdates(silent: true)
            
            // If update is available and we should show reminder
            if updateService.availableUpdate != nil && updateService.shouldShowReminder() {
                // Show update window on main thread
                await MainActor.run {
                    self.showUpdateWindow()
                }
            }
        }
    }
    
    private func showUpdateWindow() {
        guard let update = UpdateService.shared.availableUpdate else { return }
        
        let updateSheetView = UpdateSheet(update: update)
        let hostingController = NSHostingController(rootView: updateSheetView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Software Update"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

