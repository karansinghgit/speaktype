import Foundation
import AVFoundation
import ApplicationServices

class PermissionService {
    static let shared = PermissionService()
    
    // Checks if both Microphone and Accessibility permissions are currently granted
    var arePermissionsGranted: Bool {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let accessibilityStatus = AXIsProcessTrusted()
        return micStatus && accessibilityStatus
    }
    
    // Checks specific permissions individually
    var isMicGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }
}
