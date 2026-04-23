import Foundation
import Combine
import WhisperKit

struct ModelCacheLocations {
    let documentsDirectory: URL?
    let applicationSupportDirectory: URL?
    let cachesDirectory: URL?
    let homeDirectory: URL
    let temporaryDirectory: URL

    static func systemDefault(fileManager: FileManager = .default) -> ModelCacheLocations {
        ModelCacheLocations(
            documentsDirectory: fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            applicationSupportDirectory: fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first,
            cachesDirectory: fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            homeDirectory: fileManager.homeDirectoryForCurrentUser,
            temporaryDirectory: fileManager.temporaryDirectory
        )
    }
}

struct ModelCacheCleanupReport {
    let deletedPaths: [URL]
    let checkedPaths: [URL]
}

enum ModelCachePathResolver {
    private static let directRepoPath = "huggingface/models/argmaxinc/whisperkit-coreml"
    private static let hubRepoDirectoryName = "models--argmaxinc--whisperkit-coreml"

    static func candidatePaths(
        for variant: String,
        locations: ModelCacheLocations,
        fileManager: FileManager = .default
    ) -> [URL] {
        var candidates = Set<URL>()

        for root in directModelRoots(from: locations) {
            candidates.insert(root.appendingPathComponent(variant, isDirectory: true))
        }

        for root in hubRepoRoots(from: locations) {
            for match in exactVariantDirectories(named: variant, under: root, fileManager: fileManager)
            {
                candidates.insert(match)
            }
        }

        return candidates.sorted { $0.path < $1.path }
    }

    static func removeVariantDirectories(
        for variant: String,
        locations: ModelCacheLocations,
        fileManager: FileManager = .default,
        log: ((String) -> Void)? = nil
    ) -> ModelCacheCleanupReport {
        let candidates = candidatePaths(for: variant, locations: locations, fileManager: fileManager)
        var deletedPaths: [URL] = []

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            do {
                try fileManager.removeItem(at: candidate)
                deletedPaths.append(candidate)
                log?("✅ Deleted cache: \(candidate.path)")
            } catch {
                log?("❌ Failed to delete \(candidate.path): \(error)")
            }
        }

        return ModelCacheCleanupReport(deletedPaths: deletedPaths, checkedPaths: candidates)
    }

    private static func directModelRoots(from locations: ModelCacheLocations) -> [URL] {
        let baseDirectories = [
            locations.documentsDirectory,
            locations.applicationSupportDirectory,
            locations.cachesDirectory,
        ].compactMap { $0 }

        var roots = baseDirectories.map {
            $0.appendingPathComponent(directRepoPath, isDirectory: true)
        }
        roots.append(
            locations.homeDirectory
                .appendingPathComponent(".cache", isDirectory: true)
                .appendingPathComponent(directRepoPath, isDirectory: true)
        )
        roots.append(
            locations.temporaryDirectory
                .appendingPathComponent(directRepoPath, isDirectory: true)
        )
        return roots
    }

    private static func hubRepoRoots(from locations: ModelCacheLocations) -> [URL] {
        let baseDirectories = [
            locations.documentsDirectory,
            locations.applicationSupportDirectory,
            locations.cachesDirectory,
        ].compactMap { $0 }

        var roots = baseDirectories.map {
            $0.appendingPathComponent("huggingface/hub/\(hubRepoDirectoryName)", isDirectory: true)
        }
        roots.append(
            locations.homeDirectory
                .appendingPathComponent(".cache/huggingface/hub/\(hubRepoDirectoryName)", isDirectory: true)
        )
        roots.append(
            locations.temporaryDirectory
                .appendingPathComponent("huggingface/hub/\(hubRepoDirectoryName)", isDirectory: true)
        )
        return roots
    }

    private static func exactVariantDirectories(
        named variant: String,
        under root: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        guard
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var matches: [URL] = []

        for case let url as URL in enumerator {
            guard url.lastPathComponent == variant else { continue }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            matches.append(url)
            enumerator.skipDescendants()
        }

        return matches
    }
}

class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()
    
    @Published var downloadProgress: [String: Double] = [:] // Map Model Variant (String) to progress
    @Published var downloadError: [String: String] = [:] // Debugging: track errors
    @Published var isDownloading: [String: Bool] = [:]
    
    private var activeTasks: [String: Task<Void, Never>] = [:] // Track running download tasks
    
    private init() {
        // Force a custom cache directory to avoid "Multiple models found" conflicts
        setupCustomCache()
        
        // Check for already-downloaded models on launch
        Task { @MainActor in
            await refreshDownloadedModels()
            // Don't auto-select - let user explicitly pick a model which will load it
        }
    }
    
    private func setupCustomCache() {
        // Use the standard Documents/huggingface location that WhisperKit expects
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let huggingfaceCache = documentsDir.appendingPathComponent("huggingface")
        
        do {
            try FileManager.default.createDirectory(at: huggingfaceCache, withIntermediateDirectories: true)
            print("✅ Using standard HuggingFace cache at: \(huggingfaceCache.path)")
        } catch {
            print("⚠️ Failed to create huggingface directory: \(error)")
        }
        
        // Don't override HF_HUB_CACHE - let WhisperKit use its default behavior
        // This ensures compatibility with the standard HuggingFace cache structure
    }
    
    // Check which models are already downloaded and update progress dictionary
    func refreshDownloadedModels() async {
        print("🔍 Checking for already-downloaded models...")
        
        var foundModels = Set<String>()
        
        // NOTE: WhisperKit.fetchAvailableModels() returns ALL remote models, not local ones
        // We ONLY rely on disk-based verification to check what's actually downloaded
        
        // Verify models actually exist on disk with proper size validation
        let fileManager = FileManager.default
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let whisperKitPath = documentsDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
            
            if fileManager.fileExists(atPath: whisperKitPath.path) {
                if let contents = try? fileManager.contentsOfDirectory(at: whisperKitPath, includingPropertiesForKeys: [.isDirectoryKey]) {
                    print("📁 Found \(contents.count) items in WhisperKit cache at \(whisperKitPath.path)")
                    
                    for item in contents {
                        let modelName = item.lastPathComponent
                        
                        // Skip non-model directories
                        if modelName == "config.json" || modelName == ".DS_Store" {
                            continue
                        }
                        
                        // Verify this directory has actual model files (not just empty directory)
                        if let subContents = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: [.fileSizeKey]),
                           !subContents.isEmpty {
                            
                            // Check if it has the essential files for a model (must have config.json)
                            let hasConfigJson = subContents.contains(where: { $0.lastPathComponent == "config.json" })
                            let hasModelFiles = subContents.contains(where: { $0.lastPathComponent.hasSuffix(".mlmodelc") })
                            
                            if hasConfigJson && hasModelFiles {
                                // Calculate total directory size
                                let directorySize = Self.calculateDirectorySize(at: item)
                                let expectedSize = AIModel.expectedSize(for: modelName)
                                
                                // Model is complete if it's at least 80% of expected size
                                let minAcceptableSize = Int64(Double(expectedSize) * 0.8)
                                
                                if directorySize >= minAcceptableSize {
                                    print("✅ Model \(modelName) verified: \(Self.formatBytes(directorySize)) (expected ~\(Self.formatBytes(expectedSize)))")
                                    foundModels.insert(modelName)
                                } else {
                                    print("⚠️ Model \(modelName) is INCOMPLETE: \(Self.formatBytes(directorySize)) < \(Self.formatBytes(minAcceptableSize)) minimum")
                                }
                            } else {
                                print("⚠️ Model \(modelName) is incomplete (missing config.json or .mlmodelc files)")
                            }
                        }
                    }
                }
            } else {
                print("ℹ️ WhisperKit cache directory doesn't exist yet: \(whisperKitPath.path)")
                print("   Models will be downloaded on first use.")
            }
        }
        
        await MainActor.run {
            // Clear all previous progress
            self.downloadProgress.removeAll()
            
            // Only mark models that actually exist
            for variant in foundModels {
                self.downloadProgress[variant] = 1.0
                print("✅ Marked as downloaded: \(variant)")
            }
            
            if foundModels.isEmpty {
                print("❌ No models found - all will show as 'Download' buttons")
            } else {
                print("✅ Found \(foundModels.count) usable model(s)")
            }
        }
    }
    
    // Asynchronous download using WhisperKit
    func downloadModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        isDownloading[variant] = true
        downloadProgress[variant] = 0.0
        downloadError[variant] = nil
        print("Starting WhisperKit download for: \(variant)")
        
        let task = Task {
            // Debug: List what WhisperKit sees
            // Note: WhisperKit API might differ, but let's try to see if we can get info.
            // If fetchAvailableModels exists.
            
            do {
                // Determine model variant enum/string
                // Note: WhisperKit.download(variant:from:) is the likely API.
                // We use the "variant" string to fetch.
                // Assuming `WhisperKit.download(variant: variant)` acts as the fetcher.
                // Progress callback mock (since we might not have exact API signature yet):
                
                // Actual API (hypothetical based on search):
                // let model = try await WhisperKit(model: variant) 
                // OR
                // try await WhisperKit.download(variant: variant) { progress in ... }
                
                // likely: download(variant:progressCallback:) - 'from' usually has a default
                let _ = try await WhisperKit.download(variant: variant, progressCallback: { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress[variant] = progress.fractionCompleted
                    }
                })
                
                // Check if task was cancelled before declaring success
                if Task.isCancelled { return }
                
                print("Model downloaded successfully")
                
                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 1.0
                    self.activeTasks[variant] = nil // Cleanup task
                }
            } catch {
                if Task.isCancelled {
                   print("Download cancelled for \(variant)")
                   return
                }
                
                print("WhisperKit download error: \(error)")
                
                // Auto-Repair: If duplicate models found, delete and retry ONCE
                if error.localizedDescription.contains("Multiple models found") {
                     print("⚠️ Multiple models detected. Cleaning cache and retrying...")
                     
                     await MainActor.run {
                         self.downloadError[variant] = "Cleaning duplicates..."
                     }
                     
                     let log = await self.deleteModel(variant: variant)
                     print("🧹 Cleanup result: \(log)")
                     
                     // Give filesystem time to settle
                     try? await Task.sleep(nanoseconds: 2_000_000_000)
                     if Task.isCancelled { return }
                     
                     await MainActor.run {
                         self.downloadError[variant] = "Retrying download..."
                     }
                     
                     // Retry download once
                     do {
                         let _ = try await WhisperKit.download(variant: variant, progressCallback: { progress in
                             DispatchQueue.main.async {
                                 self.downloadProgress[variant] = progress.fractionCompleted
                             }
                         })
                         
                         if Task.isCancelled { return }
                         
                         print("✅ Model downloaded successfully after cleanup")
                         
                         DispatchQueue.main.async {
                             self.isDownloading[variant] = false
                             self.downloadProgress[variant] = 1.0
                             self.downloadError[variant] = nil
                             self.activeTasks[variant] = nil
                         }
                     } catch {
                         if Task.isCancelled { return }
                         print("❌ Retry failed: \(error)")
                         DispatchQueue.main.async {
                             self.isDownloading[variant] = false
                             self.downloadProgress[variant] = 0.0
                             self.downloadError[variant] = "Error: \(error.localizedDescription)\n\nTry clicking the trash icon to manually clean cache."
                             self.activeTasks[variant] = nil
                         }
                     }
                     return
                }

                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 0.0
                    self.downloadError[variant] = error.localizedDescription + "\n\n(Try Trash icon to clean cache)"
                    self.activeTasks[variant] = nil
                }
            }
        }
        
        activeTasks[variant] = task
    }
    
    // Aggressively deletes any potential cache for this variant
    func deleteModel(variant: String) async -> String {
        let fileManager = FileManager.default
        let locations = ModelCacheLocations.systemDefault(fileManager: fileManager)
        let cleanupReport = ModelCachePathResolver.removeVariantDirectories(
            for: variant,
            locations: locations,
            fileManager: fileManager,
            log: { print($0) }
        )

        let deletedCount = cleanupReport.deletedPaths.count
        let checkedPaths = cleanupReport.checkedPaths.map(\.path)

        print("🗑️ Cleanup complete. Deleted \(deletedCount) repo-owned model caches")

        if deletedCount > 0 {
            await MainActor.run {
                self.downloadProgress[variant] = 0.0
                self.isDownloading[variant] = false
            }
            return "Deleted \(deletedCount) items"
        } else {
            await MainActor.run {
                self.downloadProgress[variant] = 0.0
                self.isDownloading[variant] = false
            }
            let homePath = locations.homeDirectory.path
            return "No repo-owned cache found for '\(variant)'. Checked: \(checkedPaths.map { $0.replacingOccurrences(of: homePath, with: "~") }.joined(separator: ", "))"
        }
    }

    func cancelDownload(for variant: String) {
        if let task = activeTasks[variant] {
            task.cancel()
            activeTasks[variant] = nil
            print("Cancelled download task for \(variant)")
        }
        
        isDownloading[variant] = false
        downloadProgress[variant] = 0.0
        downloadError[variant] = nil
        
        // Delete any partial download
        Task {
            let result = await deleteModel(variant: variant)
            print("🗑️ Cleaned up partial download: \(result)")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Calculate total size of a directory recursively
    static func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    /// Format bytes into human-readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
