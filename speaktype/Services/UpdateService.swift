import Foundation
import Combine
import AppKit

/// Service to check for app updates and manage update preferences
class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var availableUpdate: AppVersion?
    @Published var isCheckingForUpdates = false
    @Published var lastCheckDate: Date?
    
    // Publisher to request UI display (e.g. show update window)
    let showUpdateWindowPublisher = PassthroughSubject<AppVersion, Never>()
    
    // User Defaults keys
    private let lastCheckDateKey = "lastUpdateCheckDate"
    private let skippedVersionKey = "skippedVersion"
    private let autoUpdateKey = "autoUpdate"
    private let lastReminderDateKey = "lastUpdateReminderDate"
    
    private init() {
        loadLastCheckDate()
    }
    
    // MARK: - Update Checking
    
    /// Check for updates from server
    func checkForUpdates(silent: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        
        await MainActor.run {
            isCheckingForUpdates = true
        }
        
        do {
            // Fetch latest release from GitHub
            // Note: Public repo access requires no auth token for simple GET
            // If hitting rate limits, might need to handle 403 or add an optional token
            let url = URL(string: "https://api.github.com/repos/karansinghgit/speaktype/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let releaseVersion = AppVersion(from: release)
            let currentVersion = AppVersion.currentVersion
            
            await MainActor.run {
                // Check if there's a newer version available
                if AppVersion.isNewerVersion(releaseVersion.version, than: currentVersion) {
                    // Don't show if user skipped this version, unless it's a manual check
                    if !silent || !self.isVersionSkipped(releaseVersion.version) {
                        self.availableUpdate = releaseVersion
                        // Notify UI to show update window
                        self.showUpdateWindowPublisher.send(releaseVersion)
                    }
                } else {
                    self.availableUpdate = nil
                }
                
                self.isCheckingForUpdates = false
                self.lastCheckDate = Date()
                self.saveLastCheckDate()
            }
        } catch {
            print("Failed to check for updates: \(error)")
            await MainActor.run {
                self.isCheckingForUpdates = false
            }
        }
    }
    
    /// Check if enough time has passed since last check (24 hours)
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        return hoursSinceLastCheck >= 24
    }
    
    /// Check if we should show reminder (every 24 hours)
    func shouldShowReminder() -> Bool {
        guard availableUpdate != nil else { return false }
        
        let lastReminder = UserDefaults.standard.object(forKey: lastReminderDateKey) as? Date
        guard let lastReminder = lastReminder else { return true }
        
        let hoursSinceReminder = Date().timeIntervalSince(lastReminder) / 3600
        return hoursSinceReminder >= 24
    }
    
    // MARK: - Version Management
    
    /// Mark a version as skipped
    func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
        availableUpdate = nil
    }
    
    /// Check if a version has been skipped
    private func isVersionSkipped(_ version: String) -> Bool {
        let skippedVersion = UserDefaults.standard.string(forKey: skippedVersionKey)
        return skippedVersion == version
    }
    
    /// Mark reminder as shown
    func markReminderShown() {
        UserDefaults.standard.set(Date(), forKey: lastReminderDateKey)
    }
    
    /// Clear skipped version (when user wants to see updates again)
    func clearSkippedVersion() {
        UserDefaults.standard.removeObject(forKey: skippedVersionKey)
    }
    
    // MARK: - Persistence
    
    private func saveLastCheckDate() {
        if let date = lastCheckDate {
            UserDefaults.standard.set(date, forKey: lastCheckDateKey)
        }
    }
    
    private func loadLastCheckDate() {
        lastCheckDate = UserDefaults.standard.object(forKey: lastCheckDateKey) as? Date
    }
    
    // MARK: - Auto Update
    
    var isAutoUpdateEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoUpdateKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoUpdateKey) }
    }
    
    // MARK: - Update Installation
    
    /// Download and install update
    func installUpdate(url: String) {
        guard let downloadURL = URL(string: url) else { return }
        NSWorkspace.shared.open(downloadURL)
    }
}
