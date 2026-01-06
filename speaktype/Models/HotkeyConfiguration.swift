//
//  HotkeyConfiguration.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation
import Carbon.HIToolbox

/// Configuration for global keyboard shortcuts
struct HotkeyConfiguration: Codable, Equatable, Identifiable {
    /// Unique identifier
    let id: UUID
    
    /// The key code (e.g., kVK_ANSI_A for 'A' key)
    let keyCode: UInt32
    
    /// Modifier flags (Command, Option, Control, Shift)
    let modifierFlags: ModifierFlags
    
    /// Human-readable description
    var description: String {
        var parts: [String] = []
        
        if modifierFlags.contains(.control) {
            parts.append("⌃")
        }
        if modifierFlags.contains(.option) {
            parts.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            parts.append("⇧")
        }
        if modifierFlags.contains(.command) {
            parts.append("⌘")
        }
        
        parts.append(keyCodeToString(keyCode))
        
        return parts.joined()
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        keyCode: UInt32,
        modifierFlags: ModifierFlags
    ) {
        self.id = id
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    
    // MARK: - Default Configurations
    
    /// Default hotkey: Control + Shift + Space
    static let `default` = HotkeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifierFlags: [.control, .shift]
    )
    
    /// Alternative: Option + Space
    static let alternativeOne = HotkeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifierFlags: [.option]
    )
    
    /// Alternative: Command + Shift + V
    static let alternativeTwo = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifierFlags: [.command, .shift]
    )
    
    // MARK: - Validation
    
    /// Check if the hotkey configuration is valid
    var isValid: Bool {
        // Must have at least one modifier
        !modifierFlags.isEmpty
    }
    
    /// Check if this conflicts with common system shortcuts
    var conflictsWithSystemShortcuts: Bool {
        // Check for common conflicts
        let commonConflicts: [(UInt32, ModifierFlags)] = [
            (UInt32(kVK_ANSI_C), [.command]), // Copy
            (UInt32(kVK_ANSI_V), [.command]), // Paste
            (UInt32(kVK_ANSI_X), [.command]), // Cut
            (UInt32(kVK_ANSI_Z), [.command]), // Undo
            (UInt32(kVK_ANSI_Q), [.command]), // Quit
            (UInt32(kVK_ANSI_W), [.command]), // Close
            (UInt32(kVK_Tab), [.command]), // Switch apps
            (UInt32(kVK_Space), [.command]), // Spotlight
        ]
        
        return commonConflicts.contains { code, flags in
            code == keyCode && flags == modifierFlags
        }
    }
}

// MARK: - Modifier Flags

/// Keyboard modifier flags
struct ModifierFlags: OptionSet, Codable, Equatable {
    let rawValue: UInt32
    
    static let command = ModifierFlags(rawValue: 1 << 0)
    static let shift = ModifierFlags(rawValue: 1 << 1)
    static let option = ModifierFlags(rawValue: 1 << 2)
    static let control = ModifierFlags(rawValue: 1 << 3)
    
    /// Convert to Carbon event modifier flags
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }
    
    /// Convert to Cocoa event modifier flags
    var cocoaFlags: UInt {
        var flags: UInt = 0
        if contains(.command) { flags |= 1 << 20 } // NSEvent.ModifierFlags.command
        if contains(.shift) { flags |= 1 << 17 } // NSEvent.ModifierFlags.shift
        if contains(.option) { flags |= 1 << 19 } // NSEvent.ModifierFlags.option
        if contains(.control) { flags |= 1 << 18 } // NSEvent.ModifierFlags.control
        return flags
    }
}

// MARK: - Key Code Mapping

/// Convert virtual key code to display string
private func keyCodeToString(_ keyCode: UInt32) -> String {
    switch Int(keyCode) {
    case kVK_Space: return "Space"
    case kVK_Return: return "Return"
    case kVK_Tab: return "Tab"
    case kVK_Delete: return "Delete"
    case kVK_Escape: return "Esc"
    case kVK_ForwardDelete: return "⌦"
    case kVK_Home: return "Home"
    case kVK_End: return "End"
    case kVK_PageUp: return "PgUp"
    case kVK_PageDown: return "PgDn"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    
    // F-keys
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    
    // Letters
    case kVK_ANSI_A: return "A"
    case kVK_ANSI_B: return "B"
    case kVK_ANSI_C: return "C"
    case kVK_ANSI_D: return "D"
    case kVK_ANSI_E: return "E"
    case kVK_ANSI_F: return "F"
    case kVK_ANSI_G: return "G"
    case kVK_ANSI_H: return "H"
    case kVK_ANSI_I: return "I"
    case kVK_ANSI_J: return "J"
    case kVK_ANSI_K: return "K"
    case kVK_ANSI_L: return "L"
    case kVK_ANSI_M: return "M"
    case kVK_ANSI_N: return "N"
    case kVK_ANSI_O: return "O"
    case kVK_ANSI_P: return "P"
    case kVK_ANSI_Q: return "Q"
    case kVK_ANSI_R: return "R"
    case kVK_ANSI_S: return "S"
    case kVK_ANSI_T: return "T"
    case kVK_ANSI_U: return "U"
    case kVK_ANSI_V: return "V"
    case kVK_ANSI_W: return "W"
    case kVK_ANSI_X: return "X"
    case kVK_ANSI_Y: return "Y"
    case kVK_ANSI_Z: return "Z"
    
    // Numbers
    case kVK_ANSI_0: return "0"
    case kVK_ANSI_1: return "1"
    case kVK_ANSI_2: return "2"
    case kVK_ANSI_3: return "3"
    case kVK_ANSI_4: return "4"
    case kVK_ANSI_5: return "5"
    case kVK_ANSI_6: return "6"
    case kVK_ANSI_7: return "7"
    case kVK_ANSI_8: return "8"
    case kVK_ANSI_9: return "9"
    
    default:
        return String(format: "Key%02X", keyCode)
    }
}

