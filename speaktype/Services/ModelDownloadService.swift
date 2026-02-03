import Foundation
import Combine
import WhisperKit

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
        // PREVENT MAIN THREAD HANG: Run heavy file system operations in a detached background task
        let foundModels = await Task.detached(priority: .userInitiated) {
            print("🔍 Checking for already-downloaded models (Background Task)...")
            
            var foundModels = Set<String>()
            let fileManager = FileManager.default
            
            // NOTE: WhisperKit.fetchAvailableModels() returns ALL remote models, not local ones
            // We ONLY rely on disk-based verification to check what's actually downloaded
            
            // Verify models actually exist on disk with proper size validation
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
                                    // Calculate total directory size (Expensive operation!)
                                    let directorySize = ModelDownloadService.calculateDirectorySize(at: item)
                                    let expectedSize = AIModel.expectedSize(for: modelName)
                                    
                                    // Model is complete if it's at least 80% of expected size
                                    let minAcceptableSize = Int64(Double(expectedSize) * 0.8)
                                    
                                    if directorySize >= minAcceptableSize {
                                        print("✅ Model \(modelName) verified: \(ModelDownloadService.formatBytes(directorySize))")
                                        foundModels.insert(modelName)
                                    } else {
                                        print("⚠️ Model \(modelName) is INCOMPLETE: \(ModelDownloadService.formatBytes(directorySize)) < \(ModelDownloadService.formatBytes(minAcceptableSize)) minimum")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("ℹ️ WhisperKit cache directory doesn't exist yet: \(whisperKitPath.path)")
                }
            }
            
            return foundModels
        }.value
        
        // Update UI on MainActor
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
    
    // Asynchronous download using WhisperKit or Hugging Face (for Parakeet models)
    func downloadModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        // Check if this is a Parakeet/NeMo model
        if NeMoService.isParakeetModel(variant) {
            downloadHuggingFaceModel(variant: variant)
        } else {
            downloadWhisperKitModel(variant: variant)
        }
    }
    
    // Download Whisper models using WhisperKit
    private func downloadWhisperKitModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        // Force SwiftUI update by reassigning dictionaries
        var updatedIsDownloading = isDownloading
        updatedIsDownloading[variant] = true
        isDownloading = updatedIsDownloading
        
        var updatedProgress = downloadProgress
        updatedProgress[variant] = 0.0
        downloadProgress = updatedProgress
        
        var updatedError = downloadError
        updatedError[variant] = nil
        downloadError = updatedError
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
                    Task { @MainActor in
                        let progressValue = progress.fractionCompleted
                        print("📥 Download progress for \(variant): \(Int(progressValue * 100))%")
                        // Force SwiftUI update by reassigning the dictionary
                        var updatedProgress = self.downloadProgress
                        updatedProgress[variant] = progressValue
                        self.downloadProgress = updatedProgress
                    }
                })
                
                // Check if task was cancelled before declaring success
                if Task.isCancelled { return }
                
                print("Model downloaded successfully")
                
                await MainActor.run {
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
                         var updatedError = self.downloadError
                         updatedError[variant] = "Cleaning duplicates..."
                         self.downloadError = updatedError
                     }
                     
                     let log = await self.deleteModel(variant: variant)
                     print("🧹 Cleanup result: \(log)")
                     
                     // Give filesystem time to settle
                     try? await Task.sleep(nanoseconds: 2_000_000_000)
                     if Task.isCancelled { return }
                     
                     await MainActor.run {
                         var updatedError = self.downloadError
                         updatedError[variant] = "Retrying download..."
                         self.downloadError = updatedError
                     }
                     
                    // Retry download once
                    do {
                        let _ = try await WhisperKit.download(variant: variant, progressCallback: { progress in
                            Task { @MainActor in
                                let progressValue = progress.fractionCompleted
                                print("📥 Download progress for \(variant) (retry): \(Int(progressValue * 100))%")
                                // Force SwiftUI update by reassigning the dictionary
                                var updatedProgress = self.downloadProgress
                                updatedProgress[variant] = progressValue
                                self.downloadProgress = updatedProgress
                            }
                        })
                        
                        if Task.isCancelled { return }
                        
                        print("✅ Model downloaded successfully after cleanup")
                        
                        await MainActor.run {
                            var updatedProgress = self.downloadProgress
                            updatedProgress[variant] = 1.0
                            self.downloadProgress = updatedProgress
                            
                            var updatedIsDownloading = self.isDownloading
                            updatedIsDownloading[variant] = false
                            self.isDownloading = updatedIsDownloading
                            
                            var updatedError = self.downloadError
                            updatedError[variant] = nil
                            self.downloadError = updatedError
                            
                            self.activeTasks[variant] = nil
                        }
                     } catch {
                         if Task.isCancelled { return }
                        print("❌ Retry failed: \(error)")
                        await MainActor.run {
                            var updatedProgress = self.downloadProgress
                            updatedProgress[variant] = 0.0
                            self.downloadProgress = updatedProgress
                            
                            var updatedIsDownloading = self.isDownloading
                            updatedIsDownloading[variant] = false
                            self.isDownloading = updatedIsDownloading
                            
                            var updatedError = self.downloadError
                            updatedError[variant] = "Error: \(error.localizedDescription)\n\nTry clicking the trash icon to manually clean cache."
                            self.downloadError = updatedError
                            
                            self.activeTasks[variant] = nil
                        }
                     }
                     return
                }

                await MainActor.run {
                    var updatedProgress = self.downloadProgress
                    updatedProgress[variant] = 0.0
                    self.downloadProgress = updatedProgress
                    
                    var updatedIsDownloading = self.isDownloading
                    updatedIsDownloading[variant] = false
                    self.isDownloading = updatedIsDownloading
                    
                    var updatedError = self.downloadError
                    updatedError[variant] = error.localizedDescription + "\n\n(Try Trash icon to clean cache)"
                    self.downloadError = updatedError
                    
                    self.activeTasks[variant] = nil
                }
            }
        }
        
        activeTasks[variant] = task
    }
    
    
    // Legacy: Download Parakeet/NeMo models from Hugging Face (Python-based)
    private func downloadHuggingFaceModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        // Force SwiftUI update by reassigning dictionaries
        var updatedIsDownloading = isDownloading
        updatedIsDownloading[variant] = true
        isDownloading = updatedIsDownloading
        
        var updatedProgress = downloadProgress
        updatedProgress[variant] = 0.0
        downloadProgress = updatedProgress
        
        var updatedError = downloadError
        updatedError[variant] = nil
        downloadError = updatedError
        
        print("Starting Hugging Face download for: \(variant)")
        
        let task = Task.detached(priority: .userInitiated) {
            do {
                // Find Python executable
                let pythonPath = self.findPythonPath()
                guard let pythonPath = pythonPath else {
                    throw NSError(domain: "ModelDownload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Python not found. Please ensure Python 3.8+ is installed."])
                }
                
                // Set up cache directory
                guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "ModelDownload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find application support directory"])
                }
                let cacheDir = appSupport.appendingPathComponent("SpeakType/huggingface")
                try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                
                // Create Python script to download model using huggingface_hub
                let downloadScript = """
                import sys
                import os
                from pathlib import Path
                
                try:
                    from huggingface_hub import snapshot_download
                    
                    repo_id = "\(variant)"
                    cache_dir = "\(cacheDir.path)"
                    
                    print(f"Downloading {repo_id} to {cache_dir}", file=sys.stderr)
                    
                    # Download model
                    local_dir = snapshot_download(
                        repo_id=repo_id,
                        cache_dir=cache_dir,
                        local_dir_use_symlinks=False
                    )
                    
                    print(f"SUCCESS: {local_dir}", file=sys.stderr)
                    print("DOWNLOAD_COMPLETE")
                    
                except ImportError:
                    print("ERROR: huggingface_hub not installed. Run: pip install huggingface_hub", file=sys.stderr)
                    sys.exit(1)
                except Exception as e:
                    print(f"ERROR: {e}", file=sys.stderr)
                    import traceback
                    traceback.print_exc()
                    sys.exit(1)
                """
                
                // Run download script
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = ["-c", downloadScript]
                
                // Set environment
                var env = ProcessInfo.processInfo.environment
                let venvPath = pythonPath.components(separatedBy: "/").dropLast().joined(separator: "/")
                if FileManager.default.fileExists(atPath: venvPath) {
                    env["VIRTUAL_ENV"] = venvPath
                    let path = env["PATH"] ?? ""
                    env["PATH"] = "\(venvPath)/bin:\(path)"
                }
                // FORCE UNBUFFERED OUTPUT so we get progress updates immediately
                env["PYTHONUNBUFFERED"] = "1"
                // Force standard terminal width to avoid tqdm doing weird things
                env["COLUMNS"] = "80"
                process.environment = env
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                // We should technically monitor stdout too, just in case
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Read progress from stderr (where tqdm writes)
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { return }
                    if let output = String(data: data, encoding: .utf8) {
                        
                        // DEBUG: Print raw output to help diagnose issues if it gets stuck
                        // Using a unique prefix so we can easily spot it in Console
                        print("🐍 [Python RAW]: \(output.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r"))")
                        
                        // Parse Progress:
                        // tqdm output can be messy with \r and ansi codes.
                        // We simply look for the LAST occurrence of a percentage pattern in the entire chunk.
                        // Pattern: Any 1-3 digits followed by %
                        
                        let pattern = "(\\d{1,3})%"
                        if let regex = try? NSRegularExpression(pattern: pattern) {
                            let range = NSRange(output.startIndex..<output.endIndex, in: output)
                            let matches = regex.matches(in: output, options: [], range: range)
                            
                            if let lastMatch = matches.last, 
                               let rangeIndex = Range(lastMatch.range(at: 1), in: output) {
                                let percentString = String(output[rangeIndex])
                                if let percent = Double(percentString) {
                                    Task { @MainActor in
                                        // Update progress
                                        self.downloadProgress[variant] = percent / 100.0
                                    }
                                }
                            }
                        }
                    }
                }
                
                try process.run()
                process.waitUntilExit()
                
                // Cleanup handler
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    await MainActor.run {
                        var updatedProgress = self.downloadProgress
                        updatedProgress[variant] = 1.0
                        self.downloadProgress = updatedProgress
                        
                        var updatedIsDownloading = self.isDownloading
                        updatedIsDownloading[variant] = false
                        self.isDownloading = updatedIsDownloading
                        
                        self.activeTasks[variant] = nil
                    }
                    print("✅ Model downloaded successfully: \(variant)")
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    
                    throw NSError(domain: "ModelDownload", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            } catch {
                await MainActor.run {
                    var updatedError = self.downloadError
                    updatedError[variant] = "Download failed: \(error.localizedDescription)"
                    self.downloadError = updatedError
                    
                    var updatedIsDownloading = self.isDownloading
                    updatedIsDownloading[variant] = false
                    self.isDownloading = updatedIsDownloading
                    
                    self.activeTasks[variant] = nil
                }
                print("❌ Download failed: \(error.localizedDescription)")
            }
        }
        
        activeTasks[variant] = task
    }
    
    // Helper to find Python executable
    nonisolated private func findPythonPath() -> String? {
        let possiblePaths = [
            "~/.nemo_env/bin/python3",
            "~/.nemo_env/bin/python",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3"
        ]
        
        for path in possiblePaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        
        // Try to find python3 in PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Ignore
        }
        
        return nil
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
        
        // 4. Check Documents/huggingface/models/argmaxinc/whisperkit-coreml (standard location)
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let whisperKitModels = documentsDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
            checkedPaths.append(whisperKitModels.path)
            deletedCount += cleanupDirectory(whisperKitModels, matchAny: [String(modelName), underscoreVariant])
        }
        
        print("🗑️ Cleanup complete. Deleted \(deletedCount) items from \(checkedPaths.count) locations")
        
        await MainActor.run {
            var updatedProgress = self.downloadProgress
            updatedProgress[variant] = 0.0
            self.downloadProgress = updatedProgress
            
            var updatedIsDownloading = self.isDownloading
            updatedIsDownloading[variant] = false
            self.isDownloading = updatedIsDownloading
        }
        
        if deletedCount > 0 {
            return "Deleted \(deletedCount) items"
        } else {
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
    nonisolated static func calculateDirectorySize(at url: URL) -> Int64 {
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
    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
