import Foundation
import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", default: .init(.space, modifiers: [.control, .option]))
}

extension Notification.Name {
    static let hotkeyTriggered = Notification.Name("hotkeyTriggered") // Legacy, can be removed
    static let recordingStartRequested = Notification.Name("recordingStartRequested")
    static let recordingStopRequested = Notification.Name("recordingStopRequested")
    static let recordingCancelRequested = Notification.Name("recordingCancelRequested")
    /// Posted when the "always show recorder pill" preference changes so the
    /// window controller can show/hide the idle pill immediately.
    static let recorderIdleVisibilityChanged = Notification.Name("recorderIdleVisibilityChanged")
}
