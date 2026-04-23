import AppKit
import Combine
import Foundation
import Security

/// Service to check for app updates and manage update preferences
class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()
    static let trustedUpdateBundleIdentifier = "com.2048labs.speaktype"
    static let trustedUpdateTeamIdentifier = "PCV4UMSRZX"

    @Published var availableUpdate: AppVersion?
    @Published var isCheckingForUpdates = false
    @Published var lastCheckDate: Date?

    // Install progress state
    @Published var isInstalling = false
    @Published var installProgress: Double = 0  // 0.0 – 1.0
    @Published var installPhase: String = ""
    @Published var installStatus: String = ""  // human-readable status
    @Published var installError: String?

    // Publisher to request UI display (e.g. show update window)
    let showUpdateWindowPublisher = PassthroughSubject<AppVersion, Never>()

    // User Defaults keys
    private let lastCheckDateKey = "lastUpdateCheckDate"
    private let skippedVersionKey = "skippedVersion"
    private let autoUpdateKey = "autoUpdate"
    private let lastReminderDateKey = "lastUpdateReminderDate"

    private var activeDownloadSession: URLSession?
    private var activeDownloadContinuation: CheckedContinuation<URL, Error>?
    private var activeDownloadDestinationURL: URL?
    private var activeDownloadStartedAt: Date?

    private override init() {
        super.init()
        loadLastCheckDate()
    }

    // MARK: - Update Checking

    /// Check for updates from server
    func checkForUpdates(silent: Bool = false) async {
        guard !isCheckingForUpdates else { return }

        await MainActor.run { isCheckingForUpdates = true }

        do {
            let url = URL(
                string: "https://api.github.com/repos/karansinghgit/speaktype/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let releaseVersion = AppVersion(from: release)
            let currentVersion = AppVersion.currentVersion

            await MainActor.run {
                if AppVersion.isNewerVersion(releaseVersion.version, than: currentVersion) {
                    if !silent || !self.isVersionSkipped(releaseVersion.version) {
                        self.availableUpdate = releaseVersion
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
            await MainActor.run { self.isCheckingForUpdates = false }
        }
    }

    /// Check if enough time has passed since last check (24 hours)
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        return Date().timeIntervalSince(lastCheck) / 3600 >= 24
    }

    /// Check if we should show the reminder (every 24 hours)
    func shouldShowReminder() -> Bool {
        guard availableUpdate != nil else { return false }
        let lastReminder = UserDefaults.standard.object(forKey: lastReminderDateKey) as? Date
        guard let lastReminder else { return true }
        return Date().timeIntervalSince(lastReminder) / 3600 >= 24
    }

    // MARK: - Version Management

    func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
        availableUpdate = nil
    }

    private func isVersionSkipped(_ version: String) -> Bool {
        UserDefaults.standard.string(forKey: skippedVersionKey) == version
    }

    func markReminderShown() {
        UserDefaults.standard.set(Date(), forKey: lastReminderDateKey)
    }

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

    /// Download the DMG, mount it, copy the .app over the running installation, and relaunch.
    func installUpdate(url downloadURLString: String) {
        guard let downloadURL = URL(string: downloadURLString) else {
            setError("Invalid download URL.")
            return
        }

        // If the URL isn't a direct asset (falls back to HTML page), open browser instead.
        guard downloadURL.pathExtension == "dmg" else {
            NSWorkspace.shared.open(downloadURL)
            return
        }

        Task {
            await MainActor.run {
                self.isInstalling = true
                self.installProgress = 0
                self.installPhase = "Downloading"
                self.installStatus = "Preparing download…"
                self.installError = nil
            }

            do {
                // 1. Download DMG with progress
                let dmgURL = try await downloadWithProgress(from: downloadURL)

                // 2. Verify the DMG before mounting it
                await MainActor.run {
                    self.installPhase = "Verifying"
                    self.installStatus = "Checking downloaded update…"
                    self.setInstallProgress(0.84)
                }
                try verifyDMG(at: dmgURL)

                // 3. Mount the DMG
                await MainActor.run {
                    self.installPhase = "Mounting"
                    self.installStatus = "Opening downloaded update…"
                    self.setInstallProgress(0.9)
                }
                let mountPoint = try mountDMG(at: dmgURL)

                // 4. Find the .app inside the mounted volume
                await MainActor.run {
                    self.installPhase = "Installing"
                    self.installStatus = "Copying new app into place…"
                    self.setInstallProgress(0.95)
                }
                let appInDMG = try findApp(in: mountPoint)

                // 5. Verify the mounted app is signed by the expected developer
                try verifyCandidateApp(at: appInDMG)

                // 6. Replace the running app
                try replaceCurrentApp(with: appInDMG)

                // 7. Detach the volume (best-effort)
                detachDMG(mountPoint: mountPoint)

                // 8. Relaunch
                await MainActor.run {
                    self.installPhase = "Relaunching"
                    self.installStatus = "Finishing update…"
                    self.setInstallProgress(1)
                }
                relaunch()

            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.installError = error.localizedDescription
                    self.installPhase = ""
                    self.installStatus = ""
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func downloadWithProgress(from url: URL) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpeakType-update-\(UUID().uuidString).dmg")

        return try await withCheckedThrowingContinuation { continuation in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            activeDownloadSession = session
            activeDownloadContinuation = continuation
            activeDownloadDestinationURL = dest
            activeDownloadStartedAt = Date()

            session.downloadTask(with: url).resume()
        }
    }

    private func verifyDMG(at dmgURL: URL) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["verify", dmgURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = Pipe()
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw UpdateError.verificationFailed
        }
    }

    private func mountDMG(at dmgURL: URL) throws -> URL {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }

        let plistData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
            let dict = plist as? [String: Any],
            let entities = dict["system-entities"] as? [[String: Any]],
            let mountEntry = entities.first(where: { $0["mount-point"] != nil }),
            let mountPath = mountEntry["mount-point"] as? String
        else {
            throw UpdateError.mountFailed
        }

        return URL(fileURLWithPath: mountPath)
    }

    private func findApp(in mountPoint: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: nil
        )
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appNotFoundInDMG
        }
        return appURL
    }

    private func verifyCandidateApp(at appURL: URL) throws {
        guard
            let bundle = Bundle(url: appURL),
            let bundleIdentifier = bundle.bundleIdentifier
        else {
            throw UpdateError.invalidCandidateApp(
                "Downloaded update is missing a bundle identifier."
            )
        }

        guard bundleIdentifier == Self.trustedUpdateBundleIdentifier else {
            throw UpdateError.invalidCandidateApp(
                "Downloaded update has an unexpected bundle identifier."
            )
        }

        let staticCode = try Self.loadStaticCode(at: appURL)
        let requirement = try Self.makeTrustedUpdateRequirement(
            bundleIdentifier: Self.trustedUpdateBundleIdentifier,
            teamIdentifier: Self.trustedUpdateTeamIdentifier
        )

        let validityStatus = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), requirement)
        guard validityStatus == errSecSuccess else {
            throw UpdateError.signatureVerificationFailed
        }

        let signingInfo = try Self.copySigningInfo(from: staticCode)
        try Self.validateSigningInfo(
            signingInfo,
            expectedBundleIdentifier: Self.trustedUpdateBundleIdentifier,
            expectedTeamIdentifier: Self.trustedUpdateTeamIdentifier
        )

        try verifyGatekeeperAcceptance(of: appURL)
    }

    private func replaceCurrentApp(with sourceApp: URL) throws {
        // Determine destination: where the current bundle lives
        let runningPath = Bundle.main.bundlePath
        let destURL = URL(fileURLWithPath: runningPath)
        let fm = FileManager.default

        // Remove old app
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        // Copy new app
        try fm.copyItem(at: sourceApp, to: destURL)
    }

    private func verifyGatekeeperAcceptance(of appURL: URL) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        proc.arguments = ["--assess", "--type", "execute", appURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = Pipe()
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw UpdateError.gatekeeperAssessmentFailed
        }
    }

    private func detachDMG(mountPoint: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["detach", mountPoint.path, "-force"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    private func relaunch() {
        // Use a shell to wait for the current process to exit, then reopen the app
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            open "\(bundlePath)"
            """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setError(_ message: String) {
        DispatchQueue.main.async {
            self.installError = message
            self.isInstalling = false
            self.installPhase = ""
            self.installStatus = ""
        }
    }

    @MainActor
    private func setInstallProgress(_ target: Double) {
        let clamped = min(max(target, installProgress), 1)
        installProgress = installProgress + (clamped - installProgress) * 0.45
        if clamped - installProgress < 0.01 {
            installProgress = clamped
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func finishDownload(_ result: Result<URL, Error>) {
        guard let continuation = activeDownloadContinuation else { return }

        activeDownloadContinuation = nil
        activeDownloadDestinationURL = nil
        activeDownloadStartedAt = nil
        activeDownloadSession?.finishTasksAndInvalidate()
        activeDownloadSession = nil

        switch result {
        case .success(let url):
            continuation.resume(returning: url)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    static func trustedUpdateRequirementString(
        bundleIdentifier: String,
        teamIdentifier: String
    ) -> String {
        """
        identifier "\(bundleIdentifier)" and anchor apple generic and certificate leaf[subject.OU] = "\(teamIdentifier)"
        """
    }

    static func validateSigningInfo(
        _ signingInfo: [String: Any],
        expectedBundleIdentifier: String,
        expectedTeamIdentifier: String
    ) throws {
        guard
            let signingIdentifier = signingInfo[kSecCodeInfoIdentifier as String] as? String,
            signingIdentifier == expectedBundleIdentifier
        else {
            throw UpdateError.invalidCandidateApp(
                "Downloaded update has an unexpected bundle identifier."
            )
        }

        guard
            let teamIdentifier = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String,
            teamIdentifier == expectedTeamIdentifier
        else {
            throw UpdateError.untrustedDeveloper
        }
    }

    private static func loadStaticCode(at appURL: URL) throws -> SecStaticCode {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(appURL as CFURL, SecCSFlags(), &staticCode)
        guard status == errSecSuccess, let staticCode else {
            throw UpdateError.signatureVerificationFailed
        }
        return staticCode
    }

    private static func makeTrustedUpdateRequirement(
        bundleIdentifier: String,
        teamIdentifier: String
    ) throws -> SecRequirement {
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(
            trustedUpdateRequirementString(
                bundleIdentifier: bundleIdentifier,
                teamIdentifier: teamIdentifier
            ) as CFString,
            SecCSFlags(),
            &requirement
        )
        guard status == errSecSuccess, let requirement else {
            throw UpdateError.signatureVerificationFailed
        }
        return requirement
    }

    private static func copySigningInfo(from staticCode: SecStaticCode) throws -> [String: Any] {
        var signingInfo: CFDictionary?
        let status = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        guard status == errSecSuccess, let info = signingInfo as? [String: Any] else {
            throw UpdateError.signatureVerificationFailed
        }
        return info
    }
}

extension UpdateService: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let safeElapsed = max(Date().timeIntervalSince(activeDownloadStartedAt ?? Date()), 0.1)
        let bytesPerSecond = Double(totalBytesWritten) / safeElapsed

        Task { @MainActor in
            self.installPhase = "Downloading"

            if totalBytesExpectedToWrite > 0 {
                let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                self.setInstallProgress(progress * 0.8)  // download = 0-80%
                self.installStatus =
                    "\(Self.byteString(totalBytesWritten)) of \(Self.byteString(totalBytesExpectedToWrite)) • \(Self.byteString(Int64(bytesPerSecond)))/s • \(Int(progress * 100))%"
            } else {
                self.installStatus =
                    "\(Self.byteString(totalBytesWritten)) downloaded • \(Self.byteString(Int64(bytesPerSecond)))/s"
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destinationURL = activeDownloadDestinationURL else {
            finishDownload(.failure(UpdateError.downloadFailed("Missing destination URL.")))
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            Task { @MainActor in
                self.installPhase = "Verifying"
                self.setInstallProgress(0.82)
                self.installStatus = "Download complete. Preparing update…"
            }

            finishDownload(.success(destinationURL))
        } catch {
            finishDownload(.failure(UpdateError.downloadFailed(error.localizedDescription)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        finishDownload(.failure(UpdateError.downloadFailed(error.localizedDescription)))
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError, Equatable {
    case downloadFailed(String)
    case mountFailed
    case appNotFoundInDMG
    case copyFailed(String)
    case verificationFailed
    case invalidCandidateApp(String)
    case signatureVerificationFailed
    case untrustedDeveloper
    case gatekeeperAssessmentFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let msg): return "Failed to download update: \(msg)"
        case .mountFailed: return "Failed to mount the update disk image."
        case .appNotFoundInDMG: return "Could not find the app inside the downloaded update."
        case .copyFailed(let msg): return "Failed to install: \(msg)"
        case .verificationFailed: return "The downloaded update failed verification."
        case .invalidCandidateApp(let message): return message
        case .signatureVerificationFailed:
            return "The downloaded update is not signed by the expected developer."
        case .untrustedDeveloper:
            return "The downloaded update was signed by an unexpected developer."
        case .gatekeeperAssessmentFailed:
            return "macOS rejected the downloaded update during Gatekeeper assessment."
        }
    }
}
