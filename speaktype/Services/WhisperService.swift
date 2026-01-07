import Foundation
import WhisperKit

@Observable
class WhisperService {
    var pipe: WhisperKit?
    var isInitialized = false
    var isTranscribing = false
    
    enum TranscriptionError: Error {
        case notInitialized
        case fileNotFound
    }
    
    func initialize() async throws {
        // Initialize WhisperKit with the base model (good balance of speed/accuracy)
        // We'll use "tiny.en" for MVP speed, can be configured later
        print("Initializing WhisperKit...")
        do {
            // "tiny.en" is a small, English-only model perfect for offline dictation
           // Explicitly request the tiny English model to minimize download size (~39MB)
           pipe = try await WhisperKit(model: "tiny.en") 
           // Note: In a real app we might want to check for model availability or download it.
           // For now, we rely on WhisperKit's default behavior or pre-downloaded models.
            isInitialized = true
            print("WhisperKit initialized successfully")
        } catch {
            print("Failed to initialize WhisperKit: \(error.localizedDescription)")
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
