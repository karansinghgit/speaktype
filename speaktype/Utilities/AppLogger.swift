import Foundation
import OSLog

/// Unified logging for SpeakType
/// Usage: AppLogger.service.info("Model downloaded")
enum AppLogger {
    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Audio recording events
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    
    /// Transcription and WhisperKit events
    static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    
    /// Model download and management
    static let models = Logger(subsystem: subsystem, category: "Models")
    
    /// Clipboard and pasteboard operations
    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    
    /// Hotkey and keyboard shortcuts
    static let hotkeys = Logger(subsystem: subsystem, category: "Hotkeys")
    
    /// UI and window management
    static let ui = Logger(subsystem: subsystem, category: "UI")
    
    /// General service operations
    static let service = Logger(subsystem: subsystem, category: "Service")
    
    /// History and persistence
    static let history = Logger(subsystem: subsystem, category: "History")
    
    /// Permissions and system access
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    
    private static let subsystem = "com.2048labs.speaktype"
}

// MARK: - Convenience Methods
extension AppLogger {
    /// Log with emoji prefix for better visual scanning
    static func info(_ message: String, category: Logger = AppLogger.service) {
        category.info("ℹ️ \(message)")
    }
    
    static func debug(_ message: String, category: Logger = AppLogger.service) {
        category.debug("🔍 \(message)")
    }
    
    static func error(_ message: String, error: Error? = nil, category: Logger = AppLogger.service) {
        if let error = error {
            category.error("❌ \(message): \(error.localizedDescription)")
        } else {
            category.error("❌ \(message)")
        }
    }
    
    static func warning(_ message: String, category: Logger = AppLogger.service) {
        category.warning("⚠️ \(message)")
    }
    
    static func success(_ message: String, category: Logger = AppLogger.service) {
        category.info("✅ \(message)")
    }
}

