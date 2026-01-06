//
//  AudioDevice.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation
import AVFoundation

/// Represents an audio input device
struct AudioDevice: Identifiable, Codable, Equatable {
    /// Unique device identifier
    let id: String
    
    /// Device name (e.g., "MacBook Pro Microphone")
    let name: String
    
    /// Device manufacturer
    let manufacturer: String?
    
    /// Whether this is the system default device
    let isDefault: Bool
    
    /// Whether the device is currently active/selected
    var isActive: Bool
    
    /// Number of input channels
    let channels: Int
    
    /// Supported sample rate
    let sampleRate: Double
    
    /// Device type (built-in, USB, Bluetooth, etc.)
    let deviceType: AudioDeviceType
    
    /// Whether the device is currently connected
    var isConnected: Bool
    
    // MARK: - Initialization
    
    init(
        id: String,
        name: String,
        manufacturer: String? = nil,
        isDefault: Bool = false,
        isActive: Bool = false,
        channels: Int = 1,
        sampleRate: Double = 48000.0,
        deviceType: AudioDeviceType = .builtin,
        isConnected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.isDefault = isDefault
        self.isActive = isActive
        self.channels = channels
        self.sampleRate = sampleRate
        self.deviceType = deviceType
        self.isConnected = isConnected
    }
    
    // MARK: - Computed Properties
    
    /// Display name with manufacturer
    var fullName: String {
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            return "\(manufacturer) - \(name)"
        }
        return name
    }
    
    /// Short description of device capabilities
    var description: String {
        let channelText = channels == 1 ? "Mono" : "\(channels) channels"
        let rateText = "\(Int(sampleRate / 1000))kHz"
        return "\(channelText), \(rateText)"
    }
    
    /// Icon name for device type
    var iconName: String {
        deviceType.iconName
    }
}

// MARK: - Audio Device Type

/// Type of audio input device
enum AudioDeviceType: String, Codable, Equatable {
    case builtin = "Built-in"
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case aggregate = "Aggregate"
    case virtual = "Virtual"
    case unknown = "Unknown"
    
    var iconName: String {
        switch self {
        case .builtin:
            return "laptopcomputer"
        case .usb:
            return "cable.connector"
        case .bluetooth:
            return "wave.3.right"
        case .aggregate:
            return "rectangle.stack"
        case .virtual:
            return "waveform.circle"
        case .unknown:
            return "mic"
        }
    }
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Factory Methods

extension AudioDevice {
    /// Create device from AVAudioSessionPortDescription
    static func from(portDescription: AVAudioSessionPortDescription) -> AudioDevice? {
        let deviceType: AudioDeviceType
        switch portDescription.portType {
        case .builtInMic:
            deviceType = .builtin
        case .usbAudio:
            deviceType = .usb
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            deviceType = .bluetooth
        default:
            deviceType = .unknown
        }
        
        return AudioDevice(
            id: portDescription.uid,
            name: portDescription.portName,
            channels: portDescription.channels?.count ?? 1,
            deviceType: deviceType
        )
    }
    
    /// System default device
    static var systemDefault: AudioDevice {
        AudioDevice(
            id: "system-default",
            name: "System Default",
            isDefault: true,
            deviceType: .builtin
        )
    }
}

// MARK: - Audio Device Preferences

/// User preferences for audio device selection
struct AudioDevicePreferences: Codable, Equatable {
    /// Input mode
    var inputMode: InputMode
    
    /// Selected device ID (when using custom device)
    var selectedDeviceId: String?
    
    /// Priority order of device IDs (when using prioritized mode)
    var priorityOrder: [String]
    
    /// Whether to automatically switch to new devices
    var autoSwitchToNewDevices: Bool
    
    // MARK: - Default
    
    static let `default` = AudioDevicePreferences(
        inputMode: .systemDefault,
        selectedDeviceId: nil,
        priorityOrder: [],
        autoSwitchToNewDevices: false
    )
}

// MARK: - Input Mode

/// Mode for selecting audio input device
enum InputMode: String, Codable, CaseIterable, Identifiable {
    case systemDefault = "System Default"
    case customDevice = "Custom Device"
    case prioritized = "Prioritized"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .systemDefault:
            return "Use system's default input device"
        case .customDevice:
            return "Select a specific input device"
        case .prioritized:
            return "Set up device priority order"
        }
    }
    
    var iconName: String {
        switch self {
        case .systemDefault:
            return "square.stack.3d.up"
        case .customDevice:
            return "mic.fill"
        case .prioritized:
            return "list.number"
        }
    }
}

