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
        
        // Setup dynamic hotkey monitoring based on user selection
        setupHotkeyMonitoring()
        
        // Check for updates on app launch
        checkForUpdatesOnLaunch()
        

    }
    
    // Critical: Prevent the app from quitting when the Mini Recorder panel closes.
    // Since we are a Menu Bar app (mostly), we must stay alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Hotkey Monitoring
    
    private func setupHotkeyMonitoring() {
        // Get selected hotkey from UserDefaults (default to Fn)
        let selectedHotkey = getSelectedHotkey()
        
        // Add global monitor for hotkey events
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let currentHotkey = self?.getSelectedHotkey() ?? .fn
            
            // Check if the pressed key matches the selected hotkey
            if event.keyCode == currentHotkey.keyCode && 
               event.modifierFlags.contains(currentHotkey.modifierFlag) {
                self?.miniRecorderController?.toggle()
            }
        }
        
        // Add local monitor for hotkey events
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let currentHotkey = self?.getSelectedHotkey() ?? .fn
            
            if event.keyCode == currentHotkey.keyCode && 
               event.modifierFlags.contains(currentHotkey.modifierFlag) {
                self?.miniRecorderController?.toggle()
            }
            return event
        }
    }
    
    private func getSelectedHotkey() -> HotkeyOption {
        // Migration: Check if old useFnKey setting exists
        if UserDefaults.standard.object(forKey: "useFnKey") != nil {
            let useFnKey = UserDefaults.standard.bool(forKey: "useFnKey")
            if useFnKey {
                // Migrate to new system
                UserDefaults.standard.set(HotkeyOption.fn.rawValue, forKey: "selectedHotkey")
                UserDefaults.standard.removeObject(forKey: "useFnKey")
                return .fn
            }
        }
        
        // Load selected hotkey
        if let rawValue = UserDefaults.standard.string(forKey: "selectedHotkey"),
           let option = HotkeyOption(rawValue: rawValue) {
            return option
        }
        
        // Default to Fn
        return .fn
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

