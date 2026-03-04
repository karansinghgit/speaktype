import Combine
import KeyboardShortcuts
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var miniRecorderController: MiniRecorderWindowController?
    var isHotkeyPressed = false
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        miniRecorderController = MiniRecorderWindowController()

        // Setup dynamic hotkey monitoring based on user selection
        setupHotkeyMonitoring()

        checkForUpdatesOnLaunch()

        UpdateService.shared.showUpdateWindowPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showUpdateWindow()
            }
            .store(in: &cancellables)

        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Emoji Picker Suppression

    private func suppressEmojiPicker() {
        // A robust way to suppress the emoji picker is to post a harmless keydown/keyup
        // with the F19 key (a non-modifier key), which immediately breaks the Globe key's double-tap
        // or press-and-release listener without causing a spurious flagsChanged event.
        let dummyKeyCode: CGKeyCode = 0x50  // F19 (80)
        let eventSource = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(
            keyboardEventSource: eventSource, virtualKey: dummyKeyCode, keyDown: true)
        {
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(
            keyboardEventSource: eventSource, virtualKey: dummyKeyCode, keyDown: false)
        {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Hotkey Monitoring

    private func setupHotkeyMonitoring() {
        // Add global monitor for hotkey events
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let currentHotkey = self.getSelectedHotkey()

            let isPressed =
                event.keyCode == currentHotkey.keyCode
                && event.modifierFlags.contains(currentHotkey.modifierFlag)

            if isPressed && !self.isHotkeyPressed {
                // Key was just pressed down
                self.isHotkeyPressed = true

                // Always suppress the emoji picker on press if using Fn
                if currentHotkey == .fn {
                    self.suppressEmojiPicker()
                }

                let recordingMode = UserDefaults.standard.integer(forKey: "recordingMode")
                if recordingMode == 1 {
                    // Toggle mode
                    if AudioRecordingService.shared.isRecording {
                        self.miniRecorderController?.stopRecording()
                    } else {
                        self.miniRecorderController?.startRecording()
                    }
                } else {
                    // Hold-to-record mode
                    self.miniRecorderController?.startRecording()
                }
            } else if !isPressed && self.isHotkeyPressed {
                // Key was just released
                self.isHotkeyPressed = false

                // Always suppress on release as well, to break the hold sequence.
                if currentHotkey == .fn {
                    self.suppressEmojiPicker()
                }

                let recordingMode = UserDefaults.standard.integer(forKey: "recordingMode")
                if recordingMode == 0 {
                    // Hold-to-record mode - stop recording when key is released
                    self.miniRecorderController?.stopRecording()
                }
            }
        }

        // Add local monitor for hotkey events (same logic)
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            let currentHotkey = self.getSelectedHotkey()

            let isPressed =
                event.keyCode == currentHotkey.keyCode
                && event.modifierFlags.contains(currentHotkey.modifierFlag)

            if isPressed && !self.isHotkeyPressed {
                self.isHotkeyPressed = true

                if currentHotkey == .fn {
                    self.suppressEmojiPicker()
                }

                let recordingMode = UserDefaults.standard.integer(forKey: "recordingMode")
                if recordingMode == 1 {
                    if AudioRecordingService.shared.isRecording {
                        self.miniRecorderController?.stopRecording()
                    } else {
                        self.miniRecorderController?.startRecording()
                    }
                } else {
                    self.miniRecorderController?.startRecording()
                }
            } else if !isPressed && self.isHotkeyPressed {
                self.isHotkeyPressed = false

                if currentHotkey == .fn {
                    self.suppressEmojiPicker()
                }

                let recordingMode = UserDefaults.standard.integer(forKey: "recordingMode")
                if recordingMode == 0 {
                    self.miniRecorderController?.stopRecording()
                }
            }
            return event
        }
    }

    private func getSelectedHotkey() -> HotkeyOption {
        // Migration: Check if old useFnKey setting exists
        if UserDefaults.standard.object(forKey: "useFnKey") != nil {
            let useFnKey = UserDefaults.standard.bool(forKey: "useFnKey")
            if useFnKey {
                UserDefaults.standard.set(HotkeyOption.fn.rawValue, forKey: "selectedHotkey")
                UserDefaults.standard.removeObject(forKey: "useFnKey")
                return .fn
            }
        }

        if let rawValue = UserDefaults.standard.string(forKey: "selectedHotkey"),
            let option = HotkeyOption(rawValue: rawValue)
        {
            return option
        }

        return .fn
    }

    // MARK: - Update Checking

    private func checkForUpdatesOnLaunch() {
        let updateService = UpdateService.shared
        let autoUpdate = UserDefaults.standard.bool(forKey: "autoUpdate")
        guard autoUpdate && updateService.shouldCheckForUpdates() else { return }

        Task {
            await updateService.checkForUpdates(silent: true)
            if updateService.availableUpdate != nil && updateService.shouldShowReminder() {
                await MainActor.run { self.showUpdateWindow() }
            }
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.styleMask.contains(.titled) else { return }
        NSApp.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            let hasVisibleWindow = NSApp.windows.contains {
                $0.isVisible && $0.styleMask.contains(.titled)
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}
