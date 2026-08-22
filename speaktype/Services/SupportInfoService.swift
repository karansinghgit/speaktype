import AVFoundation
import ApplicationServices
import Foundation

final class SupportInfoService {
    static let shared = SupportInfoService()

    private init() {}

    @discardableResult
    func copySupportInfo() -> String {
        let report = generateSupportInfo()
        ClipboardService.shared.copy(text: report)
        return report
    }

    func generateSupportInfo() -> String {
        let userDefaults = UserDefaults.standard
        let selectedModelVariant = userDefaults.string(forKey: "selectedModelVariant") ?? ""
        let selectedModelName =
            AIModel.availableModels.first(where: { $0.variant == selectedModelVariant })?.name
            ?? (selectedModelVariant.isEmpty ? "None selected" : selectedModelVariant)
        let selectedDeviceName = currentInputDeviceName()
        let languageCode = userDefaults.string(forKey: "transcriptionLanguage") ?? "auto"
        let recordingMode = userDefaults.integer(forKey: "recordingMode") == 0
            ? "Hold to record" : "Toggle"
        let showMenuBarIcon = userDefaults.object(forKey: "showMenuBarIcon") == nil
            || userDefaults.bool(forKey: "showMenuBarIcon") ? "On" : "Off"
        let hotkey = currentHotkeyDisplayName(from: userDefaults)
        let microphoneAccess = permissionStatusLabel(
            for: AVCaptureDevice.authorizationStatus(for: .audio))
        let accessibilityAccess = AXIsProcessTrusted() ? "Granted" : "Not granted"
        let memoryGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

        return """
            SpeakType Support Info
            Generated: \(timestampString())
            App version: \(Constants.App.version) (\(Constants.App.build))
            Build timestamp: \(buildTimestamp)
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Memory: \(memoryGB) GB
            Default model: \(selectedModelName)\(selectedModelVariant.isEmpty ? "" : " [\(selectedModelVariant)]")
            Recording mode: \(recordingMode)
            Hotkey: \(hotkey)
            Speech language hint: \(languageDisplayName(for: languageCode))
            Show menu bar icon: \(showMenuBarIcon)
            Input device: \(selectedDeviceName)
            Microphone access: \(microphoneAccess)
            Accessibility access: \(accessibilityAccess)
            """
    }

    private func currentHotkeyDisplayName(from userDefaults: UserDefaults) -> String {
        let rawValue = userDefaults.string(forKey: "selectedHotkey") ?? HotkeyOption.default.rawValue
        return HotkeyOption(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func currentInputDeviceName() -> String {
        let audioRecorder = AudioRecordingService.shared
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discoverySession.devices.filter { device in
            !device.localizedName.localizedCaseInsensitiveContains("Microsoft Teams")
        }

        if let selectedDeviceId = audioRecorder.selectedDeviceId,
            let device = devices.first(where: { $0.uniqueID == selectedDeviceId })
        {
            return device.localizedName
        }

        return devices.first?.localizedName ?? "Unknown"
    }

    private func languageDisplayName(for code: String) -> String {
        guard code != "auto" else { return "Auto-detect" }
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    private func permissionStatusLabel(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func timestampString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
