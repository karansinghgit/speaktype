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
    var loadingStage: String = ""  // Descriptive stage for UI

    var currentModelVariant: String = ""  // No default - must be explicitly set

    /// Device RAM in GB (cached on init)
    static let deviceRAMGB: Int = {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
    }()

    enum TranscriptionError: Error, LocalizedError {
        case notInitialized
        case fileNotFound
        case alreadyLoading
        case loadingTimeout

        var errorDescription: String? {
            switch self {
            case .notInitialized: return "Model is not initialized"
            case .fileNotFound: return "Audio file not found"
            case .alreadyLoading: return "Model loading already in progress"
            case .loadingTimeout:
                return "Model loading timed out — your Mac may not have enough RAM for this model"
            }
        }
    }

    // Init is internal to allow testing, but prefer using .shared in production
    init() {}

    // Default initialization (loads default or saved model)
    func initialize() async throws {
        try await loadModel(variant: currentModelVariant)
    }

    // Dynamic model loading with optimized WhisperKitConfig
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

        let ramGB = Self.deviceRAMGB
        print("🔄 Initializing WhisperKit with model: \(variant)...")
        print("💻 Device RAM: \(ramGB) GB")

        if let model = AIModel.availableModels.first(where: { $0.variant == variant }),
            ramGB < model.minimumRAMGB
        {
            print(
                "⚠️ WARNING: Model \(variant) recommends \(model.minimumRAMGB)GB+ RAM, device has \(ramGB)GB. Loading may fail or be very slow."
            )
        }

        isLoading = true
        isInitialized = false
        loadingStage = "Preparing model..."

        // Release existing model to free memory
        if pipe != nil {
            print("🗑️ Releasing previous model from memory...")
            pipe = nil
        }

        do {
            let documentDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let modelFolderPath = documentDirectory.appendingPathComponent(
                "huggingface/models/argmaxinc/whisperkit-coreml/\(variant)"
            ).path

            // Use WhisperKitConfig with optimized settings
            let config = WhisperKitConfig(
                model: variant,
                modelFolder: modelFolderPath,
                computeOptions: ModelComputeOptions(),  // Uses GPU + Neural Engine
                verbose: false,
                logLevel: .error,
                prewarm: true,  // Built-in model specialization (replaces manual warmup)
                load: true,
                download: false  // Already downloaded via ModelDownloadService
            )

            loadingStage = "Loading AI model..."

            // Start a watchdog timer that will flag a timeout
            let loadStart = Date()

            pipe = try await WhisperKit(config)

            let loadDuration = Date().timeIntervalSince(loadStart)
            print("⏱️ Model loaded in \(String(format: "%.1f", loadDuration))s")

            currentModelVariant = variant
            isInitialized = true
            isLoading = false
            loadingStage = ""
            print("✅ WhisperKit initialized and prewarmed with \(variant)")
        } catch {
            isLoading = false
            loadingStage = ""
            print(
                "❌ Failed to initialize WhisperKit with \(variant): \(error.localizedDescription)")
            throw error
        }
    }

    func transcribe(audioFile: URL, language: String = "auto") async throws -> String {
        guard let pipe = pipe, isInitialized else {
            throw TranscriptionError.notInitialized
        }

        guard FileManager.default.fileExists(atPath: audioFile.path) else {
            throw TranscriptionError.fileNotFound
        }

        isTranscribing = true
        defer { isTranscribing = false }

        print("Starting transcription for: \(audioFile.lastPathComponent)")

        do {
            var options = DecodingOptions()
            options.task = .transcribe
            options.language = (language == "auto") ? nil : language

            let results = try await pipe.transcribe(audioPath: audioFile.path, decodeOptions: options)
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(
                in: .whitespacesAndNewlines)

            print("Transcription complete: \(text.prefix(50))...")
            return text
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }
}
