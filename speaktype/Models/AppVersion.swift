import Foundation

/// Model representing an app version with release notes
struct AppVersion: Codable, Equatable {
    let version: String
    let buildNumber: String
    let releaseNotes: [String]
    let downloadURL: String
    let isRequired: Bool
    let releaseDate: Date
    
    /// Compare two versions (e.g., "1.67" > "1.62")
    static func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        return newVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }
    
    /// Get current app version from bundle
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Get current build number from bundle
    static var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

extension AppVersion {
    init(from release: GitHubRelease) {
        // Remove 'v' prefix if present (e.g. "v1.0.1" -> "1.0.1")
        let cleanVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        
        self.version = cleanVersion
        self.buildNumber = "0" // GitHub releases usually don't have build numbers, assume 0 or handle differently
        self.releaseNotes = release.body.components(separatedBy: "\n").filter { !$0.isEmpty }
        self.downloadURL = release.htmlUrl
        self.isRequired = false
        
        let formatter = ISO8601DateFormatter()
        self.releaseDate = formatter.date(from: release.publishedAt) ?? Date()
    }
}

/// Structure to decode GitHub API response
struct GitHubRelease: Codable {
    let tagName: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

// MARK: - Mock Data (for Previews)
extension AppVersion {
    static let mockUpdate = AppVersion(
        version: "1.67",
        buildNumber: "67",
        releaseNotes: [
            "Keyboard shortcuts to toggle specific Power Modes directly",
            "Dedicated transcript history window with global keyboard shortcut access",
            "GPT-5.2 model support",
            "Configurable audio resume delay for Bluetooth headphones",
            "Redesigned Power Mode & Enhancement UI",
            "Minor bug fixes and improvements"
        ],
        downloadURL: "https://speaktype.app/download/latest",
        isRequired: false,
        releaseDate: Date()
    )
}

