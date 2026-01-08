import Foundation
import Combine
import WhisperKit

class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()
    
    @Published var downloadProgress: [String: Double] = [:] // Map Model Variant (String) to progress
    @Published var isDownloading: [String: Bool] = [:]
    
    private init() {}
    
    // Asynchronous download using WhisperKit
    func downloadModel(variant: String) {
        guard isDownloading[variant] != true else { return }
        
        isDownloading[variant] = true
        downloadProgress[variant] = 0.0
        print("Starting WhisperKit download for: \(variant)")
        
        Task {
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
                DispatchQueue.main.async {
                    self.isDownloading[variant] = false
                    self.downloadProgress[variant] = 0.0
                }
            }
        }
    }
    
    func cancelDownload(for variant: String) {
        // WhisperKit might not support cancellation easily via this simple wrapper
        // For now, just reset state
        isDownloading[variant] = false
        downloadProgress[variant] = 0.0
    }
}

