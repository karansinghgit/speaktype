import Foundation
import WhisperKit

@Observable
class WhisperService {
    // Shared singleton instance - use this everywhere
    static let shared = WhisperService()
    
    var pipe: WhisperKit?
    private let nemoService = NeMoService()
    
    var isInitialized = false
    var isTranscribing = false
    var isLoading = false
    
    var currentModelVariant: String = "" // No default - must be explicitly set
    
    /// Check if a variant is a Whisper model (not Parakeet)
    static func isWhisperModel(_ variant: String) -> Bool {
        return !NeMoService.isParakeetModel(variant)
    }
    
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
        // Prevent concurrent loading
        guard !isLoading else {
            print("⚠️ Model loading already in progress, skipping")
            throw TranscriptionError.alreadyLoading
        }

        // Already loaded this exact model
        if isInitialized && variant == currentModelVariant {
             if NeMoService.isParakeetModel(variant) {
                 // NeMo check: assume if initialized and matches, it's good.
                 // Ideally check nemoService.isInitialized but we can trust the state flags if managed correctly.
                 print("✅ NeMo Model \(variant) already loaded, skipping")
                 return 
             } else if pipe != nil {
                 print("✅ Whisper Model \(variant) already loaded, skipping")
                 return 
             }
        }
        
        print("🔄 Initializing with model: \(variant)...")
        isLoading = true
        isInitialized = false
        
        // Release existing model to free memory
        if pipe != nil {
            print("🗑️ Releasing previous model from memory...")
            pipe = nil
        }
        
        do {
            if NeMoService.isParakeetModel(variant) {
                // Route to NeMo
                try await nemoService.loadModel(variant: variant)
                currentModelVariant = variant
                isInitialized = true
                isLoading = false
                print("✅ NeMoService initialized successfully with \(variant)")
            } else {
                // Standard WhisperKit flow
                pipe = try await WhisperKit(model: variant)
                currentModelVariant = variant
                isInitialized = true
                isLoading = false
                print("✅ WhisperKit initialized successfully with \(variant)")
            }
        } catch {
            isLoading = false
            print("❌ Failed to initialize with \(variant): \(error.localizedDescription)")
            throw error
        }
    }
    
    func transcribe(audioFile: URL) async throws -> String {
        guard isInitialized else {
            throw TranscriptionError.notInitialized
        }
        
        guard FileManager.default.fileExists(atPath: audioFile.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        isTranscribing = true
        defer { isTranscribing = false } // Ensure flag is reset even on error
        
        print("Starting transcription for: \(audioFile.lastPathComponent)")
        
        do {
            if NeMoService.isParakeetModel(currentModelVariant) {
                // Route to NeMo
                return try await nemoService.transcribe(audioFile: audioFile)
            } else {
                guard let pipe = pipe else { throw TranscriptionError.notInitialized }
                
                // Transcribe the audio file with WhisperKit
                let results = try await pipe.transcribe(audioPath: audioFile.path)
                
                // Combine all segments into a single string
                let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("Transcription complete: \(text.prefix(50))...")
                return text
            }
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }
}
