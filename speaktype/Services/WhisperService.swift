import Foundation
import WhisperKit

@Observable
class WhisperService {
    var pipe: WhisperKit?
    private let nemoService = NeMoService()
    
    var isInitialized = false
    var isTranscribing = false
    
    var currentModelVariant: String = "openai_whisper-base.en" // Default
    
    /// Check if a variant is a Whisper model (not Parakeet)
    static func isWhisperModel(_ variant: String) -> Bool {
        return !NeMoService.isParakeetModel(variant)
    }
    
    enum TranscriptionError: Error {
        case notInitialized
        case fileNotFound
    }
    
    // Default initialization (loads default or saved model)
    func initialize() async throws {
        // You might want to pull from UserDefaults here if you want persistence in Service
        // For now, allow the View to drive the variant selection via loadModel
        try await loadModel(variant: currentModelVariant)
    }
    
    // Dynamic model loading
    func loadModel(variant: String) async throws {
        if isInitialized && variant == currentModelVariant {
             if NeMoService.isParakeetModel(variant) {
                 // NeMo check
                 return 
             } else if pipe != nil {
                 return // Whisper already loaded
             }
        }
        
        print("Initializing with model: \(variant)...")
        isInitialized = false
        
        if NeMoService.isParakeetModel(variant) {
            // Route to NeMo
            do {
                try await nemoService.loadModel(variant: variant)
                currentModelVariant = variant
                isInitialized = true
                print("NeMoService initialized successfully with \(variant)")
            } catch {
                print("Failed to initialize NeMoService with \(variant): \(error.localizedDescription)")
                throw error
            }
        } else {
            // Standard WhisperKit flow
            do {
                pipe = try await WhisperKit(model: variant)
                currentModelVariant = variant
                isInitialized = true
                print("WhisperKit initialized successfully with \(variant)")
            } catch {
                print("Failed to initialize WhisperKit with \(variant): \(error.localizedDescription)")
                throw error
            }
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
