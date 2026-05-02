import AppKit
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", default: .init(.space, modifiers: [.control, .option]))
}

extension Notification.Name {
    static let hotkeyTriggered = Notification.Name("hotkeyTriggered") // Legacy, can be removed
    static let recordingStartRequested = Notification.Name("recordingStartRequested")
    static let recordingStopRequested = Notification.Name("recordingStopRequested")
    static let recordingCancelRequested = Notification.Name("recordingCancelRequested")
}
