import Foundation
import WhisperKit

@Observable
class WhisperService {
    // Shared singleton instance - use this everywhere
    static let shared = WhisperService()
    
    var pipe: WhisperKit?
    var isInitialized = false
    var isTranscribing = false
    var isLoading = false
    
    var currentModelVariant: String = "" // No default - must be explicitly set
    
    enum TranscriptionError: Error {
        case notInitialized
        case fileNotFound
        case alreadyLoading
    }
    
    // Init is internal to allow testing, but prefer using .shared in production
    init() {}
    
    // Default initialization (loads default or saved model)
    func initialize() async throws {
        // You might want to pull from UserDefaults here if you want persistence in Service
        // For now, allow the View to drive the variant selection via loadModel
        try await loadModel(variant: currentModelVariant)
    }
    
    // Dynamic model loading
    func loadModel(variant: String) async throws {
        // Already loaded this exact model
        if isInitialized && variant == currentModelVariant && pipe != nil {
            print("✅ Model \(variant) already loaded, skipping")
            return
        }
        
        // Prevent concurrent loading
        guard !isLoading else {
            print("⚠️ Model loading already in progress, skipping")
            throw TranscriptionError.alreadyLoading
        }
        
        print("🔄 Initializing WhisperKit with model: \(variant)...")
        isLoading = true
        isInitialized = false
        
        // Release existing model to free memory
        if pipe != nil {
            print("🗑️ Releasing previous model from memory...")
            pipe = nil
        }
        
        do {
            pipe = try await WhisperKit(model: variant)
            currentModelVariant = variant
            isInitialized = true
            isLoading = false
            print("✅ WhisperKit initialized successfully with \(variant)")
        } catch {
            isLoading = false
            print("❌ Failed to initialize WhisperKit with \(variant): \(error.localizedDescription)")
            throw error
        }
    }
    
    func transcribe(audioFile: URL) async throws -> String {
        guard let pipe = pipe, isInitialized else {
            throw TranscriptionError.notInitialized
        }
        
        guard FileManager.default.fileExists(atPath: audioFile.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        isTranscribing = true
        defer { isTranscribing = false } // Ensure flag is reset even on error
        
        print("Starting transcription for: \(audioFile.lastPathComponent)")
        
        do {
            // Transcribe the audio file
            // Note: WhisperKit 0.9.x API might vary, assuming standard transcribe flow
            let results = try await pipe.transcribe(audioPath: audioFile.path)
            
            // Combine all segments into a single string
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("Transcription complete: \(text.prefix(50))...")
            return text
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }
}
