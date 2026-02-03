import SwiftUI
import KeyboardShortcuts
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var miniRecorderController: MiniRecorderWindowController?
    private var isHotkeyPressed = false
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the controller
        miniRecorderController = MiniRecorderWindowController()
        
        // Setup dynamic hotkey monitoring based on user selection
        setupHotkeyMonitoring()
        
        // Check for updates on app launch
        checkForUpdatesOnLaunch()
        
        // Listen for update window requests
        UpdateService.shared.showUpdateWindowPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showUpdateWindow()
            }
            .store(in: &cancellables)
        

    }
    
    // Critical: Prevent the app from quitting when the Mini Recorder panel closes.
    // Since we are a Menu Bar app (mostly), we must stay alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Hotkey Monitoring
    
    private func setupHotkeyMonitoring() {
        // Get selected hotkey from UserDefaults (default to Fn)
        _ = getSelectedHotkey()
        
        // Add global monitor for hotkey events
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let currentHotkey = self.getSelectedHotkey()
            
            // Check if the hotkey is currently pressed
            let isPressed = event.keyCode == currentHotkey.keyCode && 
                           event.modifierFlags.contains(currentHotkey.modifierFlag)
            
            if isPressed && !self.isHotkeyPressed {
                // Key was just pressed down - start recording
                self.isHotkeyPressed = true
                self.miniRecorderController?.startRecording()
            } else if !isPressed && self.isHotkeyPressed {
                // Key was just released - stop recording
                self.isHotkeyPressed = false
                self.miniRecorderController?.stopRecording()
            }
        }
        
        // Add local monitor for hotkey events
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            let currentHotkey = self.getSelectedHotkey()
            
            let isPressed = event.keyCode == currentHotkey.keyCode && 
                           event.modifierFlags.contains(currentHotkey.modifierFlag)
            
            if isPressed && !self.isHotkeyPressed {
                self.isHotkeyPressed = true
                self.miniRecorderController?.startRecording()
            } else if !isPressed && self.isHotkeyPressed {
                self.isHotkeyPressed = false
                self.miniRecorderController?.stopRecording()
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

