import Foundation
import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", default: .init(.space, modifiers: [.control, .option]))
}

extension Notification.Name {
    static let hotkeyTriggered = Notification.Name("hotkeyTriggered")
}
