import Foundation
import WhisperKit

@Observable
class WhisperService {
    // Shared singleton instance - use this everywhere
    static let shared = WhisperService()
    private static let autoEditEnabledKey = "enableAutoEdit"
    private static let customReplacementRulesKey = "customReplacementRules"
    private static let placeholderPatterns = [
        #"\[(?:BLANK_AUDIO|SILENCE)\]"#,
        #"<\|nospeech\|>"#,
        #"\[\s*S\s*\]"#,
    ]
    private static let fillerWordPattern =
        #"(?i)(^|[\s,.;:!?])(?:uh+|um+|umm+|uhm+|erm+|hmm+)(?=$|[\s,.;:!?])[,.;:!?]?"#
    private static let noiseLabelTerms = [
        "applause",
        "background noise",
        "blank audio",
        "breathing",
        "cough",
        "coughing",
        "exhale",
        "heartbeat",
        "indistinct",
        "inaudible",
        "inhale",
        "laughing",
        "laughter",
        "loud noise",
        "muffled speech",
        "music",
        "noise",
        "silence",
        "sigh",
        "sighs",
        "sniffing",
        "static",
        "unclear speech",
        "unintelligible",
        "wind",
        "wind blowing",
        "wind noise",
    ]
    private static let bracketedNoisePattern: String = {
        let escaped = noiseLabelTerms.map(NSRegularExpression.escapedPattern(for:)).joined(
            separator: "|")
        return #"[\[\(]\s*(?:"# + escaped + #")\s*[\]\)]"#
    }()

    var pipe: WhisperKit?
    var isInitialized = false
    var isTranscribing = false
    var isLoading = false
    var loadingStage: String = ""  // Descriptive stage for UI
    var loadingModelVariant: String = ""
    var loadingStartedAt: Date?

    var currentModelVariant: String = ""  // No default - must be explicitly set
    private var lastLoadDuration: TimeInterval?

    @MainActor private var activeLoadTask: Task<Void, Error>?
    @MainActor private var activeLoadVariant: String = ""
    @MainActor private var activeLoadToken: UUID?

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
    @MainActor
    func initialize() async throws {
        try await loadModel(variant: currentModelVariant)
    }

    // Dynamic model loading with optimized WhisperKitConfig
    @MainActor
    func loadModel(variant: String) async throws {
        // Already loaded this exact model
        if isInitialized && variant == currentModelVariant && pipe != nil {
            print("✅ Model \(variant) already loaded, skipping")
            return
        }

        if let activeLoadTask {
            let inFlightVariant = activeLoadVariant

            if inFlightVariant == variant {
                loadingStage = "Model is still warming up..."
                print("⏳ Model \(variant) load already in progress, waiting for completion")
                try await activeLoadTask.value
                return
            }

            loadingStage = "Finishing current model load..."
            print("⏳ Waiting for current model load (\(inFlightVariant)) to finish before loading \(variant)")
            do {
                try await activeLoadTask.value
            } catch {
                // If another model failed to warm up, still try the model the caller asked for.
                print(
                    "⚠️ In-flight model load (\(inFlightVariant)) failed while waiting: \(error.localizedDescription). Continuing with \(variant)."
                )
            }

            if isInitialized && variant == currentModelVariant && pipe != nil {
                print("✅ Model \(variant) became ready while waiting, skipping duplicate load")
                return
            }
        }

        let token = UUID()
        let task = Task { @MainActor in
            try await self.performModelLoad(variant: variant)
        }
        activeLoadTask = task
        activeLoadVariant = variant
        activeLoadToken = token

        defer {
            if activeLoadToken == token {
                activeLoadTask = nil
                activeLoadVariant = ""
                activeLoadToken = nil
            }
        }

        try await task.value
    }

    @MainActor
    private func performModelLoad(variant: String) async throws {
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
        loadingModelVariant = variant
        loadingStartedAt = Date()
        loadingStage = "Preparing \(modelDisplayName(for: variant))..."

        // Release existing model to free memory
        if pipe != nil {
            loadingStage = "Switching models and freeing memory..."
            print("🗑️ Releasing previous model from memory...")
            pipe = nil
        }

        do {
            // Prefer the current Application Support location; fall back to the legacy
            // Documents location so users who downloaded before the move keep working.
            let newModelFolder = ModelStorage.whisperKitModelsDir
                .appendingPathComponent(variant)
            var modelFolder = newModelFolder
            if !FileManager.default.fileExists(atPath: newModelFolder.path),
                let legacyFolder = ModelStorage.legacyModelsDir?.appendingPathComponent(variant),
                FileManager.default.fileExists(atPath: legacyFolder.path)
            {
                modelFolder = legacyFolder
            }

            // Use WhisperKitConfig with optimized settings.
            // `downloadBase` keeps any tokenizer configs WhisperKit fetches out of
            // ~/Documents (the root cause of model-load failures on macOS 15, #38).
            let config = WhisperKitConfig(
                model: variant,
                downloadBase: ModelStorage.whisperKitBase,
                modelFolder: modelFolder.path,
                computeOptions: ModelComputeOptions(),  // Uses GPU + Neural Engine
                verbose: false,
                logLevel: .error,
                prewarm: true,  // Built-in model specialization (replaces manual warmup)
                load: true,
                download: false  // Already downloaded via ModelDownloadService
            )

            loadingStage = "Loading model into memory..."

            // Start a watchdog timer that will flag a timeout
            let loadStart = Date()

            pipe = try await WhisperKit(config)

            let loadDuration = Date().timeIntervalSince(loadStart)
            lastLoadDuration = loadDuration
            print("⏱️ Model loaded in \(String(format: "%.1f", loadDuration))s")

            currentModelVariant = variant
            isInitialized = true
            isLoading = false
            loadingStage = ""
            loadingModelVariant = ""
            loadingStartedAt = nil
            print("✅ WhisperKit initialized and prewarmed with \(variant)")
        } catch {
            isLoading = false
            loadingStage = ""
            loadingModelVariant = ""
            loadingStartedAt = nil
            print(
                "❌ Failed to initialize WhisperKit with \(variant): \(error.localizedDescription)")
            throw error
        }
    }

    private func modelDisplayName(for variant: String) -> String {
        AIModel.availableModels.first(where: { $0.variant == variant })?.name ?? variant
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
            let options = decodingOptions(for: language)
            let results = try await pipe.transcribe(audioPath: audioFile.path, decodeOptions: options)
            let text = Self.normalizedTranscription(
                from: results.map { $0.text }.joined(separator: " "))

            print("Transcription complete: \(text.prefix(50))...")
            return text
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Transcribe a background audio chunk without affecting the global `isTranscribing` flag.
    /// Chunk files are automatically deleted after transcription.
    func transcribeChunk(audioFile: URL, language: String = "auto") async throws -> String {
        guard let pipe = pipe, isInitialized else {
            throw TranscriptionError.notInitialized
        }

        guard FileManager.default.fileExists(atPath: audioFile.path) else {
            // Chunk file may have been cleaned up already - return empty gracefully
            return ""
        }

        print("🔪 Chunk transcription started: \(audioFile.lastPathComponent)")

        let results = try await pipe.transcribe(
            audioPath: audioFile.path,
            decodeOptions: decodingOptions(for: language)
        )
        let text = Self.normalizedTranscription(from: results.map { $0.text }.joined(separator: " "))

        print("🔪 Chunk done: \(text.prefix(40))...")
        // Clean up temp chunk file after transcription
        try? FileManager.default.removeItem(at: audioFile)
        return text
    }

    private func decodingOptions(for language: String) -> DecodingOptions {
        var options = DecodingOptions()
        options.task = .transcribe
        options.language = (language == "auto") ? nil : language
        return options
    }

    static func normalizedTranscription(from rawText: String) -> String {
        var normalized = rawText

        for pattern in placeholderPatterns {
            normalized = normalized.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }

        normalized = normalized.replacingOccurrences(
            of: bracketedNoisePattern,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )

        normalized = normalized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        normalized = applyAutoEdit(to: normalized)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct AutoEditRule {
        let source: String
        let replacement: String
    }

    private static func applyAutoEdit(to text: String) -> String {
        guard UserDefaults.standard.bool(forKey: autoEditEnabledKey) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var edited = text.replacingOccurrences(
            of: fillerWordPattern,
            with: "$1",
            options: .regularExpression
        )

        for rule in customReplacementRules() {
            edited = replace(rule.source, with: rule.replacement, in: edited)
        }

        edited = edited.replacingOccurrences(
            of: #"\s+([,.;:!?])"#,
            with: "$1",
            options: .regularExpression
        )
        edited = edited.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return edited.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func customReplacementRules() -> [AutoEditRule] {
        let rawRules = UserDefaults.standard.string(forKey: customReplacementRulesKey) ?? ""

        return rawRules
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { return nil }

                for separator in ["=>", "->", "="] {
                    let parts = line.components(separatedBy: separator)
                    guard parts.count >= 2 else { continue }

                    let source = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let replacement = parts[1...].joined(separator: separator)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !source.isEmpty else { return nil }
                    return AutoEditRule(source: source, replacement: replacement)
                }

                return nil
            }
    }

    private static func replace(_ source: String, with replacement: String, in text: String) -> String {
        let escapedSource = NSRegularExpression.escapedPattern(for: source)
            .replacingOccurrences(of: " ", with: #"\s+"#)
        let needsLeadingBoundary = source.first?.isLetter == true || source.first?.isNumber == true
        let needsTrailingBoundary = source.last?.isLetter == true || source.last?.isNumber == true
        let pattern =
            "\(needsLeadingBoundary ? #"\b"# : "")\(escapedSource)\(needsTrailingBoundary ? #"\b"# : "")"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        // Escape the user-supplied replacement so `$` / `\` are treated literally,
        // not as regex template tokens.
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
