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
                let path = try await WhisperKit.download(variant: variant, progressCallback: { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress[variant] = progress.fractionCompleted
                    }
                })
                
                print("Model downloaded to: \(path)")
                
                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 1.0
                }
            } catch {
                print("WhisperKit download error: \(error)")
                
                // Auto-Repair: If duplicate models found, delete and retry ONCE
                if error.localizedDescription.contains("Multiple models found") {
                     print("Corruption detected. cleaning cache and retrying...")
                     Task { @MainActor in
                         self.downloadError[variant] = "Repairing..."
                     }
                     
                     let log = await self.deleteModel(variant: variant)
                     
                     Task { @MainActor in
                         self.downloadError[variant] = "Repairing... \(log)"
                         try? await Task.sleep(nanoseconds: 1_000_000_000) // Sleep 1s to let FS settle
                     }
                     
                     // Retry download
                     Task {
                         do {
                             let path = try await WhisperKit.download(variant: variant, progressCallback: { progress in
                                 DispatchQueue.main.async {
                                     self.downloadProgress[variant] = progress.fractionCompleted
                                 }
                             })
                             DispatchQueue.main.async {
                                 self.isDownloading[variant] = false
                                 self.downloadProgress[variant] = 1.0
                                 self.downloadError[variant] = nil
                             }
                         } catch {
                             DispatchQueue.main.async {
                                 self.isDownloading[variant] = false
                                 self.downloadProgress[variant] = 0.0
                                 self.downloadError[variant] = error.localizedDescription
                             }
                         }
                     }
                     return
                }

                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 0.0
                    // Append hint
                    self.downloadError[variant] = error.localizedDescription + "\n(Try Trash icon)"
                }
            }
        }
    }
    
    // Aggressively deletes any potential cache for this variant
    func deleteModel(variant: String) async -> String {
        let fileManager = FileManager.default
        let searchDirs: [FileManager.SearchPathDirectory] = [.documentDirectory, .applicationSupportDirectory, .cachesDirectory]
        
        // "openai/whisper-large-v3" -> "whisper-large-v3"
        let variantParts = variant.split(separator: "/")
        let modelName = variantParts.last ?? Substring(variant)
        
        var deletedCount = 0
        var checkedPaths: [String] = []
        
        // 1. Check Standard macOS Paths
        for searchDir in searchDirs {
            guard let baseDir = fileManager.urls(for: searchDir, in: .userDomainMask).first else { continue }
            
            // Check ./huggingface/models
            let hfDir = baseDir.appendingPathComponent("huggingface/models")
            checkedPaths.append(hfDir.path) // Checks: ~/Library/Application Support/huggingface/models
            deletedCount += cleanupDirectory(hfDir, match: modelName)
            
            // Check ./ (root of Documents/Support, sometimes WhisperKit dumps here)
            // check baseDir.path
            deletedCount += cleanupDirectory(baseDir, match: modelName)
        }
        
        // 2. Check ~/.cache (Common for Python/Unix HF tools)
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let dotCache = homeDir.appendingPathComponent(".cache/huggingface/models")
        checkedPaths.append(dotCache.path)
        deletedCount += cleanupDirectory(dotCache, match: modelName)
        
        // 3. Explicit Container Check (Fallback)
        let container = homeDir.appendingPathComponent("Library/Containers/org.speaktype.speaktype/Data/Documents/huggingface/models")
        checkedPaths.append(container.path)
        deletedCount += cleanupDirectory(container, match: modelName)
        
        // 4. Check Temporary Directory
        let tempDir = fileManager.temporaryDirectory
        // check tempDir/huggingface/models and just tempDir
        let tempHf = tempDir.appendingPathComponent("huggingface/models")
        checkedPaths.append(tempDir.path)
        checkedPaths.append(tempHf.path)
        deletedCount += cleanupDirectory(tempDir, match: modelName)
        deletedCount += cleanupDirectory(tempHf, match: modelName)
        
        if deletedCount > 0 {
            return "Deleted \(deletedCount) items"
        } else {
            // Return only first 2 checked paths for brevity if they exist, or just summary
            return "No match for '\(modelName)' in \(checkedPaths.count) locations. checked: \(checkedPaths.map { $0.replacingOccurrences(of: homeDir.path, with: "~") }.joined(separator: ", "))"
        }
    }
    
    private func cleanupDirectory(_ dir: URL, match: Substring) -> Int {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return 0 }
        
        var count = 0
        for url in contents {
             if url.lastPathComponent.contains(match) {
                 do {
                     try fileManager.removeItem(at: url)
                     print("Deleted corrupted cache: \(url.path)")
                     count += 1
                 } catch {
                     print("Failed to delete \(url.path): \(error)")
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
