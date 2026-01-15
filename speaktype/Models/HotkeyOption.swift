import Foundation
import AppKit

/// Hotkey options for triggering SpeakType recording
enum HotkeyOption: String, Codable, CaseIterable, Identifiable {
    case fn = "fn"
    case rightCommand = "rightCommand"
    case leftCommand = "leftCommand"
    case rightControl = "rightControl"
    case leftControl = "leftControl"
    case rightOption = "rightOption"
    case leftOption = "leftOption"
    
    var id: String { rawValue }
    
    /// Display name with appropriate symbols
    var displayName: String {
        switch self {
        case .fn:
            return "Fn"
        case .rightCommand:
            return "Right ⌘"
        case .leftCommand:
            return "Left ⌘"
        case .rightControl:
            return "Right ⌃"
        case .leftControl:
            return "Left ⌃"
        case .rightOption:
            return "Right ⌥"
        case .leftOption:
            return "Left ⌥"
        }
    }
    
    /// macOS keycode for this modifier key
    var keyCode: UInt16 {
        switch self {
        case .fn:
            return 63
        case .rightCommand:
            return 54
        case .leftCommand:
            return 55
        case .rightControl:
            return 62
        case .leftControl:
            return 59
        case .rightOption:
            return 61
        case .leftOption:
            return 58
        }
    }
    
    /// Modifier flag to check when key is pressed
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .fn:
            return .function
        case .rightCommand, .leftCommand:
            return .command
        case .rightControl, .leftControl:
            return .control
        case .rightOption, .leftOption:
            return .option
        }
    }
    
    /// Default hotkey option
    static var `default`: HotkeyOption {
        return .fn
    }
}

// SwiftUI Binding support
import SwiftUI

extension HotkeyOption {
    /// Create a Binding for SwiftUI from UserDefaults key
    static func binding(forKey key: String, default defaultValue: HotkeyOption = .default) -> Binding<HotkeyOption> {
        Binding(
            get: {
                guard let rawValue = UserDefaults.standard.string(forKey: key),
                      let option = HotkeyOption(rawValue: rawValue) else {
                    return defaultValue
                }
                return option
            },
            set: { newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: key)
            }
        )
    }
}
