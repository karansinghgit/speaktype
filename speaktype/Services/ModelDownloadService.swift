import Combine
import Foundation
import WhisperKit

class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()

    static let storagePathKey = "modelStoragePath"

    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadError: [String: String] = [:]
    @Published var isDownloading: [String: Bool] = [:]

    private var activeTasks: [String: Task<Void, Never>] = [:]

    /// Root directory passed as `downloadBase` to WhisperKit/HubApi.
    /// Defaults to ~/Library/Application Support/SpeakType/Models per Apple guidelines.
    var modelStorageURL: URL {
        let custom = UserDefaults.standard.string(forKey: Self.storagePathKey) ?? ""
        if !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SpeakType/Models")
    }

    /// Path where WhisperKit stores individual model folders.
    var whisperKitModelsURL: URL {
        modelStorageURL.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
    }

    private init() {
        Task { @MainActor in
            await refreshDownloadedModels()
        }
    }
    
    // Check which models are already downloaded and update progress dictionary
    func refreshDownloadedModels() async {
        print("🔍 Checking for already-downloaded models...")
        
        var foundModels = Set<String>()
        
        // NOTE: WhisperKit.fetchAvailableModels() returns ALL remote models, not local ones
        // We ONLY rely on disk-based verification to check what's actually downloaded
        
        // Verify models actually exist on disk with proper size validation
        let fileManager = FileManager.default
        let whisperKitPath = whisperKitModelsURL

        if fileManager.fileExists(atPath: whisperKitPath.path),
           let contents = try? fileManager.contentsOfDirectory(at: whisperKitPath, includingPropertiesForKeys: [.isDirectoryKey]) {
            print("📁 Found \(contents.count) items in WhisperKit cache at \(whisperKitPath.path)")

            for item in contents {
                let modelName = item.lastPathComponent
                if modelName == "config.json" || modelName == ".DS_Store" { continue }

                if let subContents = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: [.fileSizeKey]),
                   !subContents.isEmpty {
                    let hasConfigJson = subContents.contains(where: { $0.lastPathComponent == "config.json" })
                    let hasModelFiles = subContents.contains(where: { $0.lastPathComponent.hasSuffix(".mlmodelc") })

                    if hasConfigJson && hasModelFiles {
                        let directorySize = Self.calculateDirectorySize(at: item)
                        let expectedSize = AIModel.expectedSize(for: modelName)
                        let minAcceptableSize = Int64(Double(expectedSize) * 0.8)

                        if directorySize >= minAcceptableSize {
                            print("✅ Model \(modelName) verified: \(Self.formatBytes(directorySize))")
                            foundModels.insert(modelName)
                        } else {
                            print("⚠️ Model \(modelName) incomplete: \(Self.formatBytes(directorySize)) < \(Self.formatBytes(minAcceptableSize))")
                        }
                    }
                }
            }
        } else {
            print("ℹ️ No model storage directory yet — models will be downloaded on first use.")
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
        
        let storageURL = modelStorageURL
        let task = Task {
            do {
                // Create storage directory only now, on first actual download
                try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)

                _ = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: storageURL,
                    progressCallback: { progress in
                        DispatchQueue.main.async {
                            self.downloadProgress[variant] = progress.fractionCompleted
                        }
                    }
                )
                
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
                         _ = try await WhisperKit.download(
                             variant: variant,
                             downloadBase: storageURL,
                             progressCallback: { progress in
                                 DispatchQueue.main.async {
                                     self.downloadProgress[variant] = progress.fractionCompleted
                                 }
                             }
                         )
                         
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
        let searchDirs: [FileManager.SearchPathDirectory] = [.documentDirectory, .applicationSupportDirectory, .cachesDirectory]
        
        // Parse variant: "openai/whisper-medium" or "openai_whisper-medium"
        let variantParts = variant.split(separator: "/")
        let modelName = variantParts.last ?? Substring(variant)
        
        // Also search for underscore version: openai_whisper-medium
        let underscoreVariant = variant.replacingOccurrences(of: "/", with: "_")
        
        var deletedCount = 0
        var checkedPaths: [String] = []
        
        print("🗑️ Searching for model caches matching: '\(modelName)' or '\(underscoreVariant)'")
        
        // 1. Check Standard macOS Paths
        for searchDir in searchDirs {
            guard let baseDir = fileManager.urls(for: searchDir, in: .userDomainMask).first else { continue }
            
            // Check ./huggingface/models (HuggingFace cache)
            let hfModelsDir = baseDir.appendingPathComponent("huggingface/models")
            checkedPaths.append(hfModelsDir.path)
            deletedCount += cleanupDirectory(hfModelsDir, matchAny: [String(modelName), underscoreVariant])
            
            // Check ./huggingface/hub (Alternative HF structure)
            let hfHubDir = baseDir.appendingPathComponent("huggingface/hub")
            checkedPaths.append(hfHubDir.path)
            deletedCount += cleanupDirectory(hfHubDir, matchAny: [String(modelName), underscoreVariant])
            
            // Skip the old SpeakType-specific directory (no longer used)
            
            // Check root directory (sometimes models are here)
            deletedCount += cleanupDirectory(baseDir, matchAny: [String(modelName), underscoreVariant])
        }
        
        // 2. Check ~/.cache (Common for Python/Unix HF tools)
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let dotCacheModels = homeDir.appendingPathComponent(".cache/huggingface/models")
        checkedPaths.append(dotCacheModels.path)
        deletedCount += cleanupDirectory(dotCacheModels, matchAny: [String(modelName), underscoreVariant])
        
        let dotCacheHub = homeDir.appendingPathComponent(".cache/huggingface/hub")
        checkedPaths.append(dotCacheHub.path)
        deletedCount += cleanupDirectory(dotCacheHub, matchAny: [String(modelName), underscoreVariant])
        
        // 3. Check Temporary Directory
        let tempDir = fileManager.temporaryDirectory
        let tempHf = tempDir.appendingPathComponent("huggingface")
        checkedPaths.append(tempHf.path)
        deletedCount += cleanupDirectory(tempHf, matchAny: [String(modelName), underscoreVariant])
        deletedCount += cleanupDirectory(tempDir, matchAny: [String(modelName), underscoreVariant])
        
        // 4. Check configured storage location (whisperKitModelsURL)
        let configuredModelsPath = whisperKitModelsURL
        checkedPaths.append(configuredModelsPath.path)
        deletedCount += cleanupDirectory(configuredModelsPath, matchAny: [String(modelName), underscoreVariant])

        // 5. Check legacy Documents/huggingface location (old default, kept for cleanup)
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let legacyPath = documentsDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
            checkedPaths.append(legacyPath.path)
            deletedCount += cleanupDirectory(legacyPath, matchAny: [String(modelName), underscoreVariant])
        }
        
        print("🗑️ Cleanup complete. Deleted \(deletedCount) items from \(checkedPaths.count) locations")
        
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
            return "No match for '\(modelName)' in \(checkedPaths.count) locations. checked: \(checkedPaths.map { $0.replacingOccurrences(of: homeDir.path, with: "~") }.joined(separator: ", "))"
        }
    }
    
    private func cleanupDirectory(_ dir: URL, matchAny patterns: [String]) -> Int {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return 0 }
        
        var count = 0
        for url in contents {
            let fileName = url.lastPathComponent
            // Check if any pattern matches
            let matches = patterns.contains { pattern in
                fileName.contains(pattern) || fileName.contains(pattern.replacingOccurrences(of: "/", with: "--"))
            }
            
            if matches {
                do {
                    try fileManager.removeItem(at: url)
                    print("✅ Deleted cache: \(url.lastPathComponent)")
                    count += 1
                } catch {
                    print("❌ Failed to delete \(url.lastPathComponent): \(error)")
                }
            }
        }
        return count
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
