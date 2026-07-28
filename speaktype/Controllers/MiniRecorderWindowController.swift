import Cocoa
import SwiftUI

class MiniRecorderWindowController: NSObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var lastActiveApp: NSRunningApplication?
    private var shouldRestoreClipboardAfterAutoPaste: Bool {
        UserDefaults.standard.object(forKey: "restoreClipboardAfterAutoPaste") as? Bool ?? true
    }

    /// When on, the resting pill stays on screen even when idle. Default off:
    /// the recorder appears only while dictating and hides afterward (issue #100).
    private var alwaysShowIdlePill: Bool {
        UserDefaults.standard.bool(forKey: "alwaysShowRecorderPill")
    }

    /// Where the pill sits on screen. Read from UserDefaults each time it is
    /// repositioned, so the latest value is always used.
    private var pillPosition: PillPosition {
        if let raw = UserDefaults.standard.string(forKey: PillPosition.defaultsKey),
            let pos = PillPosition(rawValue: raw)
        {
            return pos
        }
        return .defaultPosition
    }

    /// Prepare the resting pill. Called once at launch. When "always show" is on
    /// the pill lives on screen and morphs into the recording HUD; when off it
    /// stays hidden until recording starts.
    func showIdleRecorder() {
        if panel == nil {
            setupPanel()
        }
        guard let panel = panel else { return }

        positionPanel()
        // Idle pill is a passive indicator — let clicks pass through to whatever is
        // behind it so the transparent window never blocks the desktop or dock.
        panel.ignoresMouseEvents = true

        if alwaysShowIdlePill, !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// React to the "always show recorder pill" preference changing at runtime.
    func applyIdleVisibilityPreference() {
        if panel == nil {
            setupPanel()
        }
        guard let panel = panel else { return }

        if alwaysShowIdlePill {
            positionPanel()
            panel.ignoresMouseEvents = true
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else if panel.ignoresMouseEvents {
            // Only hide when idle — during an active session the panel is
            // interactive (ignoresMouseEvents == false), so leave it alone.
            panel.orderOut(nil)
        }
    }

    /// React to the "recorder pill position" preference changing at runtime.
    /// Defer the move while a recording is in progress so the HUD doesn't
    /// teleport under the user's cursor; the next `startRecording()` /
    /// `showIdleRecorder()` will place it in the new spot.
    func applyPillPosition() {
        if panel == nil {
            setupPanel()
        }
        guard let panel = panel else { return }
        guard !AudioRecordingService.shared.isRecording else { return }
        guard panel.isVisible else { return }
        positionPanel()
    }

    /// Reposition the pill when the display configuration changes (external
    /// monitor connected/disconnected, dock resized, etc.) so it doesn't end
    /// up off-screen relative to the new layout. Deferred mid-recording so the
    /// HUD doesn't jump under the user's cursor; the next `startRecording()`
    /// / `showIdleRecorder()` will place it in the new spot.
    func handleScreenParametersChanged() {
        guard !AudioRecordingService.shared.isRecording else { return }
        positionPanel()
    }

    // Start recording - show panel and begin recording
    func startRecording() {
        // Capture previous app to restore focus later
        lastActiveApp = NSWorkspace.shared.frontmostApplication

        if panel == nil {
            setupPanel()
        }

        guard let panel = panel else { return }

        positionPanel()
        // Become interactive so the recording HUD (stop dot, hover controls) works.
        panel.ignoresMouseEvents = false

        if !panel.isVisible {
            print("Showing Mini Recorder Panel")
            panel.orderFrontRegardless()
        }

        // Trigger instant recording
        NotificationCenter.default.post(name: .recordingStartRequested, object: nil)
    }

    /// Position the panel on its current screen according to the user's chosen
    /// `PillPosition`. Safe to call repeatedly (on show and on every resize).
    private func positionPanel() {
        guard let panel = panel else { return }
        let screen = panel.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let origin = PillPosition.origin(
            for: pillPosition,
            panelSize: panel.frame.size,
            visibleFrame: visibleFrame
        )
        let rounded = NSPoint(x: origin.x.rounded(), y: origin.y.rounded())
        if panel.frame.origin != rounded {
            panel.setFrameOrigin(rounded)
        }
    }

    /// Return the pill to its passive resting state. When "always show" is off
    /// (the default) this hides the recorder so it only appears while dictating.
    private func returnToIdle() {
        guard let panel = panel else { return }
        panel.ignoresMouseEvents = true
        if !alwaysShowIdlePill {
            panel.orderOut(nil)
        } else {
            // Pick up any position change that was deferred mid-recording.
            positionPanel()
        }
    }

    // Stop recording - trigger transcription and paste
    func stopRecording() {
        // 1. Hide recorder immediately - REMOVED so it shows "Transcribing..."
        // panel?.orderOut(nil)

        // Keep focus unchanged while the hotkey is still being released.
        // Re-activation happens later during commit, right before auto-paste.
        NotificationCenter.default.post(name: .recordingStopRequested, object: nil)
    }

    func cancelRecording() {
        NotificationCenter.default.post(name: .recordingCancelRequested, object: nil)
    }

    private func setupPanel() {
        // Initialize View with callbacks
        let recorderView = MiniRecorderView(
            onCommit: { [weak self] text in
                self?.handleCommit(text: text)
            },
            onCancel: { [weak self] in
                // Don't hide — the pill stays on screen and settles back to idle.
                self?.returnToIdle()
            }
        )

        // Initialize hosting controller with transparent background view
        // Wrap in AnyView because .background() changes the type from MiniRecorderView to some View
        hostingController = NSHostingController(
            rootView: AnyView(recorderView.background(Color.clear)))

        // Fixed window, big enough for the largest phase. The pill morphs purely in
        // SwiftUI, centered inside. A window that never resizes means the animation
        // is smooth with no boundary clipping.
        let fixedSize = NSSize(width: 520, height: 84)
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: fixedSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        p.isOpaque = false
        p.backgroundColor = .clear
        p.ignoresMouseEvents = true  // idle by default — clicks pass through

        // Use the hosting view directly as the content view (NOT contentViewController)
        // so the window size is never driven by the SwiftUI content, and clamp the
        // size so nothing can resize it.
        if let hostView = hostingController?.view {
            hostView.frame = NSRect(origin: .zero, size: fixedSize)
            hostView.autoresizingMask = [.width, .height]
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = NSColor.clear.cgColor
            p.contentView = hostView
        }
        p.minSize = fixedSize
        p.maxSize = fixedSize
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = false  // stay put — positioned by positionPanel() per user preference
        p.hasShadow = false  // Disable system shadow to avoid transparency artifacts (View has its own shadow)

        // Window Behavior
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false  // Keep floating even if focus lost
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = p
    }

    private func handleCommit(text: String) {
        Task {
            // 1. Copy to clipboard for manual paste, or snapshot it first if the user wants it restored.
            let previousClipboard: ClipboardService.ClipboardSnapshot?
            if shouldRestoreClipboardAfterAutoPaste {
                previousClipboard = ClipboardService.shared.copyForTemporaryPaste(text: text)
            } else {
                previousClipboard = nil
                ClipboardService.shared.copy(text: text)
            }

            // 2. Settle the pill back to its resting state (keep it on screen).
            await MainActor.run {
                self.returnToIdle()
            }

            // 3. Check accessibility - if not granted, just copy to clipboard silently
            let accessibilityTrusted = ClipboardService.shared.isAccessibilityTrusted

            if !accessibilityTrusted {
                // Text is already copied to clipboard, just return
                // Don't show annoying popup - user can paste manually with Cmd+V
                print(
                    "⚠️ Accessibility not granted - text copied to clipboard, user can paste with Cmd+V"
                )
                return
            }

            // 4. Re-activate the target app
            if let app = self.lastActiveApp {
                _ = await MainActor.run {
                    app.activate()
                }
            }

            // 5. Wait for focus
            try? await Task.sleep(nanoseconds: 500_000_000)

            // 6. Paste using CGEvent (Accessibility permission only)
            await MainActor.run {
                ClipboardService.shared.paste()
            }

            guard let previousClipboard else { return }

            try? await Task.sleep(nanoseconds: 350_000_000)

            await MainActor.run {
                ClipboardService.shared.restore(previousClipboard, ifCurrentStringMatches: text)
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText =
            "SpeakType needs Accessibility permission to automatically paste transcriptions into the active app.\n\nYour transcription has been copied to the clipboard.\n\nTo enable auto-paste, grant permission in:\nSystem Settings → Privacy & Security → Accessibility"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
