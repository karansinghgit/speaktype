import Foundation
import Combine
import FluidAudio
import WhisperKit

struct ModelCacheCleanupReport {
    let deletedPaths: [URL]
    let checkedPaths: [URL]
}

/// Resolves and removes cache directories for a WhisperKit model variant.
///
/// Safety (from #65): cleanup is limited to the exact per-variant subdirectories
/// SpeakType itself owns — never a broad substring match over generic locations
/// (Caches root, home dir, temp, `.cache/huggingface`) that could delete unrelated
/// files. Storage layout (from #90 / `ModelStorage`): the only roots SpeakType
/// writes CoreML variants into are the current Application Support location and the
/// legacy `~/Documents/huggingface` location.
enum ModelCachePathResolver {
    /// The WhisperKit model roots SpeakType owns and is allowed to clean up:
    /// `<AppSupport>/SpeakType/models/argmaxinc/whisperkit-coreml` plus the legacy
    /// `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml`.
    static func repoOwnedModelRoots() -> [URL] {
        var roots = [ModelStorage.whisperKitModelsDir]
        if let legacy = ModelStorage.legacyModelsDir { roots.append(legacy) }
        return roots
    }

    /// Exact per-variant candidate directories under the given repo-owned roots.
    ///
    /// For each root we consider both the slash ("openai/whisper-medium") and the
    /// underscore ("openai_whisper-medium") spelling of the variant, plus any exact
    /// `variant`-named directory found nested under the root (e.g. a hub-style
    /// `.../snapshots/<hash>/<variant>` layout). Directories whose names merely
    /// *contain* the variant (e.g. "<variant>-backup") are never matched.
    static func candidatePaths(
        for variant: String,
        roots: [URL],
        fileManager: FileManager = .default
    ) -> [URL] {
        var candidates = Set<URL>()

        for root in roots {
            for name in variantDirectoryNames(for: variant) {
                candidates.insert(root.appendingPathComponent(name, isDirectory: true))
            }
            for match in exactVariantDirectories(named: variant, under: root, fileManager: fileManager) {
                candidates.insert(match)
            }
        }

        return candidates.sorted { $0.path < $1.path }
    }

    static func removeVariantDirectories(
        for variant: String,
        roots: [URL],
        fileManager: FileManager = .default,
        log: ((String) -> Void)? = nil
    ) -> ModelCacheCleanupReport {
        let candidates = candidatePaths(for: variant, roots: roots, fileManager: fileManager)
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

    private static func variantDirectoryNames(for variant: String) -> [String] {
        Array(Set([variant, variant.replacingOccurrences(of: "/", with: "_")]))
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
        // Move any models left in the legacy ~/Documents/huggingface location into
        // Application Support. No directory is created eagerly — a fresh install
        // leaves no trace until the user actually downloads a model.
        ModelStorage.migrateLegacyModelsIfNeeded()

        // Check for already-downloaded models on launch
        Task { @MainActor in
            await refreshDownloadedModels()
            // Don't auto-select - let user explicitly pick a model which will load it
        }
    }
    
    // Check which models are already downloaded and update progress dictionary
    func refreshDownloadedModels() async {
        print("🔍 Checking for already-downloaded models...")
        
        var foundModels = Set<String>()
        
        // NOTE: WhisperKit.fetchAvailableModels() returns ALL remote models, not local ones
        // We ONLY rely on disk-based verification to check what's actually downloaded
        
        let fileManager = FileManager.default

        // Verify models actually exist on disk with proper size validation.
        // Scan the current Application Support location plus the legacy Documents
        // location (in case a migration move failed or hasn't run yet).
        var scanDirs = [ModelStorage.whisperKitModelsDir]
        if let legacy = ModelStorage.legacyModelsDir { scanDirs.append(legacy) }
        for dir in scanDirs {
            scanWhisperKitModels(in: dir, into: &foundModels)
        }
        
        // Check Parakeet (FluidAudio) models, which live in their own cache dir.
        for variant in ParakeetCatalog.variants {
            let version = ParakeetCatalog.version(for: variant)
            let cacheDir = AsrModels.defaultCacheDirectory(for: version)
            if fileManager.fileExists(atPath: cacheDir.path),
               let contents = try? fileManager.contentsOfDirectory(atPath: cacheDir.path),
               !contents.isEmpty {
                foundModels.insert(variant)
                print("✅ Parakeet model \(variant) found in cache")
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
    
    // Scan a WhisperKit CoreML models directory and insert any complete variants
    // (verified by required files + ~80% of expected size) into `foundModels`.
    private func scanWhisperKitModels(in whisperKitPath: URL, into foundModels: inout Set<String>) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: whisperKitPath.path) else {
            print("ℹ️ WhisperKit cache directory doesn't exist yet: \(whisperKitPath.path)")
            return
        }

        guard let contents = try? fileManager.contentsOfDirectory(at: whisperKitPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }

        print("📁 Found \(contents.count) items in WhisperKit cache at \(whisperKitPath.path)")

        for item in contents {
            let modelName = item.lastPathComponent

            // Skip non-model directories
            if modelName == "config.json" || modelName == ".DS_Store" {
                continue
            }

            // Verify this directory has actual model files (not just empty directory)
            guard let subContents = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: [.fileSizeKey]),
                  !subContents.isEmpty else {
                continue
            }

            // Check if it has the essential files for a model (must have config.json)
            let hasConfigJson = subContents.contains(where: { $0.lastPathComponent == "config.json" })
            let hasModelFiles = subContents.contains(where: { $0.lastPathComponent.hasSuffix(".mlmodelc") })

            guard hasConfigJson && hasModelFiles else {
                print("⚠️ Model \(modelName) is incomplete (missing config.json or .mlmodelc files)")
                continue
            }

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
        }
    }

    // Asynchronous download using WhisperKit
    func downloadModel(variant: String) {
        guard isDownloading[variant] != true else { return }

        // Route Parakeet variants to FluidAudio.
        if AIModel.engineKind(for: variant) == .parakeet {
            downloadParakeetModel(variant: variant)
            return
        }

        isDownloading[variant] = true
        downloadProgress[variant] = 0.0
        downloadError[variant] = nil
        // Create the storage directory now, on first download — never eagerly on launch.
        ModelStorage.ensureWhisperKitModelsDir()
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
                let _ = try await WhisperKit.download(variant: variant, downloadBase: ModelStorage.whisperKitBase, progressCallback: { progress in
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
                         let _ = try await WhisperKit.download(variant: variant, downloadBase: ModelStorage.whisperKitBase, progressCallback: { progress in
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
    
    // Download a Parakeet model via FluidAudio (CoreML weights from Hugging Face).
    private func downloadParakeetModel(variant: String) {
        isDownloading[variant] = true
        downloadProgress[variant] = 0.0
        downloadError[variant] = nil
        print("Starting FluidAudio (Parakeet) download for: \(variant)")

        let version = ParakeetCatalog.version(for: variant)

        let task = Task {
            do {
                _ = try await AsrModels.download(
                    version: version,
                    progressHandler: { progress in
                        DispatchQueue.main.async {
                            self.downloadProgress[variant] = progress.fractionCompleted
                        }
                    })

                if Task.isCancelled { return }
                print("Parakeet model downloaded successfully")

                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 1.0
                    self.activeTasks[variant] = nil
                }
            } catch {
                if Task.isCancelled {
                    print("Parakeet download cancelled for \(variant)")
                    return
                }
                print("FluidAudio download error: \(error)")
                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 0.0
                    self.downloadError[variant] = error.localizedDescription
                    self.activeTasks[variant] = nil
                }
            }
        }

        activeTasks[variant] = task
    }

    // Aggressively deletes any potential cache for this variant
    func deleteModel(variant: String) async -> String {
        // Parakeet models are managed by FluidAudio in its own cache directory.
        if AIModel.engineKind(for: variant) == .parakeet {
            let version = ParakeetCatalog.version(for: variant)
            let cacheDir = AsrModels.defaultCacheDirectory(for: version)
            try? FileManager.default.removeItem(at: cacheDir)
            await MainActor.run {
                self.downloadProgress[variant] = 0.0
                self.isDownloading[variant] = false
            }
            return "Deleted Parakeet model cache for \(variant)"
        }

        let fileManager = FileManager.default
        // Only ever touch the WhisperKit model directories SpeakType itself owns:
        // the current Application Support location and the legacy Documents location.
        // Deletion is limited to the exact per-variant subdirectories under those
        // roots — no broad substring matching over Caches/home/temp that could nuke
        // unrelated files (the pre-#65 behavior).
        let roots = ModelCachePathResolver.repoOwnedModelRoots()
        let cleanupReport = ModelCachePathResolver.removeVariantDirectories(
            for: variant,
            roots: roots,
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
            let homePath = fileManager.homeDirectoryForCurrentUser.path
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
