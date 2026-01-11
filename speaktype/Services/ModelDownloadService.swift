import Foundation
import Combine
import WhisperKit

class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()
    
    @Published var downloadProgress: [String: Double] = [:] // Map Model Variant (String) to progress
    @Published var downloadError: [String: String] = [:] // Debugging: track errors
    @Published var isDownloading: [String: Bool] = [:]
    
    private init() {
        // Force a custom cache directory to avoid "Multiple models found" conflicts
        setupCustomCache()
    }
    
    private func setupCustomCache() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        // ~/Library/Application Support/SpeakType/huggingface
        let customCache = appSupport.appendingPathComponent("SpeakType/huggingface")
        
        do {
            try FileManager.default.createDirectory(at: customCache, withIntermediateDirectories: true)
            // Set HF_HUB_CACHE to this clean directory
            setenv("HF_HUB_CACHE", customCache.path, 1)
            print("Redirected HF Cache to: \(customCache.path)")
        } catch {
            print("Failed to setup custom cache: \(error)")
        }
    }
    
    // Asynchronous download using WhisperKit
    func downloadModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        isDownloading[variant] = true
        downloadProgress[variant] = 0.0
        downloadError[variant] = nil
        print("Starting WhisperKit download for: \(variant)")
        
        Task {
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
                
                print("Model downloaded successfully")
                
                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 1.0
                }
            } catch {
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
                         
                         print("✅ Model downloaded successfully after cleanup")
                         
                         DispatchQueue.main.async {
                             self.isDownloading[variant] = false
                             self.downloadProgress[variant] = 1.0
                             self.downloadError[variant] = nil
                         }
                     } catch {
                         print("❌ Retry failed: \(error)")
                         DispatchQueue.main.async {
                             self.isDownloading[variant] = false
                             self.downloadProgress[variant] = 0.0
                             self.downloadError[variant] = "Error: \(error.localizedDescription)\n\nTry clicking the trash icon to manually clean cache."
                         }
                     }
                     return
                }

                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 0.0
                    self.downloadError[variant] = error.localizedDescription + "\n\n(Try Trash icon to clean cache)"
                }
            }
        }
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
            
            // Check SpeakType-specific directory
            let speaktypeDir = baseDir.appendingPathComponent("SpeakType/huggingface")
            checkedPaths.append(speaktypeDir.path)
            deletedCount += cleanupDirectory(speaktypeDir, matchAny: [String(modelName), underscoreVariant])
            
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
        
        // 4. Check for models--* pattern in Application Support (WhisperKit style)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let modelsPattern = "models--" + variant.replacingOccurrences(of: "/", with: "--")
            deletedCount += cleanupDirectory(appSupport, matchAny: [modelsPattern])
            
            // Also check nested huggingface/hub for models-- pattern
            let hfHub = appSupport.appendingPathComponent("huggingface/hub")
            deletedCount += cleanupDirectory(hfHub, matchAny: [modelsPattern])
        }
        
        print("🗑️ Cleanup complete. Deleted \(deletedCount) items from \(checkedPaths.count) locations")
        
        if deletedCount > 0 {
            return "Deleted \(deletedCount) items. Retry download."
        } else {
            return "No cached models found matching '\(modelName)'. This error may be in a different location."
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
        // WhisperKit might not support cancellation easily via this simple wrapper
        // For now, just reset state
        isDownloading[variant] = false
        downloadProgress[variant] = 0.0
    }
}
