import Foundation
import WhisperKit

@Observable
class WhisperService {
    var pipe: WhisperKit?
    var isInitialized = false
    var isTranscribing = false
    
    var currentModelVariant: String = "openai_whisper-base" // Default
    
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
        if isInitialized && variant == currentModelVariant && pipe != nil {
             return // Already loaded
        }
        
        print("Initializing WhisperKit with model: \(variant)...")
        isInitialized = false
        
        do {
            // WhisperKit.download(variant:) logic handles checking if consistent
            // But here we want the PIPE, so we init WhisperKit(model: variant)
            // Note: If model isn't downloaded, this might fail or trigger download depending on library version.
            // Ideally, we ensure it's downloaded first via ModelDownloadService, but WhisperKit init often handles it.
            
            pipe = try await WhisperKit(model: variant)
            currentModelVariant = variant
            isInitialized = true
            print("WhisperKit initialized successfully with \(variant)")
        } catch {
            print("Failed to initialize WhisperKit with \(variant): \(error.localizedDescription)")
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
