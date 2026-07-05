import AVFoundation
import Combine
import CoreMedia
import Foundation

class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()  // Shared instance for settings/dashboard sync

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var audioFrequency: Float = 0.0  // Normalized 0...1 representation of pitch
    /// Rolling window of recent normalized mic levels for the live waveform UI.
    /// Updated on every audio buffer while recording (independent of any view timer).
    @Published var liveWaveSamples: [Float] = []
    private static let maxLiveWaveSamples = 48
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceId: String? {
        didSet {
            setupSession()
            // If a dictation is in flight (device unplugged mid-recording, or a
            // switch from settings), restart the rebuilt session so capture
            // continues — setupSession alone leaves the new session stopped and
            // the recording would silently go dead until the user stops.
            if isRecording {
                audioQueue.async {
                    if self.captureSession?.isRunning != true {
                        print("🎤 Restarting capture session after device change mid-recording")
                        self.captureSession?.startRunning()
                    }
                }
            }
            // Persist so the selection survives app restarts.
            if let selectedDeviceId {
                UserDefaults.standard.set(selectedDeviceId, forKey: Self.selectedDeviceDefaultsKey)
            }
        }
    }

    private static let selectedDeviceDefaultsKey = "selectedAudioDeviceId"

    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    public private(set) var recordingStartTime: Date?
    private var currentFileURL: URL?
    private var isSessionStarted = false
    private var setupTask: Task<Void, Never>?
    private var isStopping = false  // Flag to prevent appending during stop
    private var idleSessionStopWorkItem: DispatchWorkItem?

    private var shouldDiscardCurrentRecordingOutput = false
    private var smoothedAudioLevel: Float = 0.0
    private var smoothedAudioFrequency: Float = 0.0

    // Coalesce level/waveform publishes to ~30 Hz (audioQueue-confined).
    // Publishing three @Published values per audio buffer re-rendered the
    // whole observing pill 50-100x/s for no visible gain.
    private var pendingWavePeak: Float = 0
    private var lastLevelPublishUptime: TimeInterval = 0
    private static let levelPublishInterval: TimeInterval = 1.0 / 30.0

    /// Buffers captured before the asset writer is ready (audioQueue-confined).
    /// Without this, everything the user says between pressing the hotkey and
    /// the writer being wired up — session cold start plus writer setup — was
    /// silently dropped, cutting off the first word(s) of every dictation.
    private var pendingSampleBuffers: [CMSampleBuffer] = []
    private static let maxPendingSampleBuffers = 600

    private let audioQueue = DispatchQueue(label: "com.speaktype.audioQueue")

    private func validatedAudioFileURL(
        at url: URL,
        writer: AVAssetWriter?,
        label: String
    ) -> URL? {
        if let writer {
            switch writer.status {
            case .completed:
                break
            case .failed:
                AppLogger.error(
                    "\(label) writer failed",
                    error: writer.error,
                    category: AppLogger.audio
                )
                return nil
            case .cancelled:
                AppLogger.warning("\(label) writer was cancelled", category: AppLogger.audio)
                return nil
            default:
                AppLogger.warning(
                    "\(label) writer finished with status \(String(describing: writer.status.rawValue))",
                    category: AppLogger.audio
                )
                return nil
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.warning("\(label) file missing after finishWriting", category: AppLogger.audio)
            return nil
        }

        do {
            _ = try AVAudioFile(forReading: url)
            return url
        } catch {
            AppLogger.error(
                "\(label) file is unreadable after finishWriting",
                error: error,
                category: AppLogger.audio
            )
            return nil
        }
    }

    private func resetMainWriterState() {
        assetWriter = nil
        assetWriterInput = nil
        currentFileURL = nil
        isSessionStarted = false
        smoothedAudioLevel = 0.0
        smoothedAudioFrequency = 0.0
    }

    override init() {
        super.init()
        // Restore the persisted device before discovery completes; AVCaptureDevice(uniqueID:)
        // resolves it directly, and fetchAvailableDevices() falls back if it is gone.
        // (didSet does not fire during init, matching the previous lazy session setup.)
        selectedDeviceId = UserDefaults.standard.string(forKey: Self.selectedDeviceDefaultsKey)
        fetchAvailableDevices()
        if selectedDeviceId == nil, let first = availableDevices.first {
            selectedDeviceId = first.uniqueID
        }

        // Listen for device changes (plug/unplug)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChange),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChange),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )
    }

    @objc private func handleDeviceChange(_ notification: Notification) {
        print("Audio device change detected")
        fetchAvailableDevices()
    }

    func fetchAvailableDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        DispatchQueue.main.async {
            self.availableDevices = discoverySession.devices.filter { device in
                !device.localizedName.localizedCaseInsensitiveContains("Microsoft Teams")
            }
            // Keep the current (possibly persisted) selection if it is still
            // connected; otherwise fall back to the first available device, or
            // clear it when no inputs remain.
            let selectionIsAvailable = self.availableDevices.contains {
                $0.uniqueID == self.selectedDeviceId
            }
            if !selectionIsAvailable {
                if let first = self.availableDevices.first {
                    print("🎤 Falling back to available input device: \(first.localizedName)")
                    self.selectedDeviceId = first.uniqueID
                } else {
                    self.selectedDeviceId = nil
                }
            }
        }
    }

    /// Builds the capture session. Returns whether a usable input was installed
    /// — false when the selected device is missing or can't be added, which
    /// leaves an inputless session that would capture nothing.
    @discardableResult
    func setupSession() -> Bool {
        captureSession?.stopRunning()
        captureSession = AVCaptureSession()

        guard let deviceId = selectedDeviceId,
            let device = AVCaptureDevice(uniqueID: deviceId),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession?.canAddInput(input) == true
        else {
            print("Failed to find or add device with ID: \(selectedDeviceId ?? "nil")")
            return false
        }

        captureSession?.addInput(input)

        audioOutput = AVCaptureAudioDataOutput()
        // Pin a fixed Linear PCM output format so the live level meter always sees a
        // known sample layout. Without this, AVCaptureAudioDataOutput delivers the
        // device's *native* format, which a communication app (Zoom/FaceTime/Meet)
        // can switch mid-call to a layout processAudioLevel can't decode. The file
        // writer keeps working (it appends buffers as-is, so transcription is fine),
        // but the waveform flatlines to 0 — text works, no waveform. Forcing 16-bit
        // interleaved PCM keeps the meter fed regardless of what else holds the mic.
        audioOutput?.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        if captureSession?.canAddOutput(audioOutput!) == true {
            captureSession?.addOutput(audioOutput!)
            audioOutput?.setSampleBufferDelegate(self, queue: audioQueue)
        }

        // Don't start session here - only start when recording begins
        // This prevents continuous CPU usage when idle
        return true
    }

    /// Pre-warm the capture session so first recording starts instantly
    func prewarmSession() {
        if captureSession == nil { setupSession() }

        audioQueue.async {
            guard let session = self.captureSession, !session.isRunning else { return }
            print("🎤 Pre-warming audio capture session...")
            session.startRunning()
            // Give it a moment to fully initialize
            Thread.sleep(forTimeInterval: 0.3)
            print("🎤 Audio capture session ready")
            self.scheduleIdleSessionStop()
        }
    }

    /// Stop the prewarmed capture session when the recorder is no longer visible.
    func stopSessionIfIdle() {
        audioQueue.async {
            self.cancelIdleSessionStop()
            guard !self.isRecording, let session = self.captureSession, session.isRunning else {
                return
            }
            print("🎤 Stopping idle audio capture session")
            session.stopRunning()
        }
    }

    /// Start recording. `onStarted` fires with `true` once capture actually
    /// begins and `false` if permission is denied — so callers can flip their
    /// "recording" UI only when a take is really underway, instead of guessing
    /// before the (possibly asynchronous) permission answer.
    func startRecording(onStarted: ((Bool) -> Void)? = nil) {
        guard !isRecording else {
            onStarted?(false)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginAuthorizedRecording(onStarted: onStarted)
        case .notDetermined:
            // First run: wait for the user's answer to the system prompt.
            // Starting immediately used to record into a mic we might never
            // get, producing an empty take even when the user granted access —
            // and callers must not enter "recording" state until this resolves.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    guard granted else {
                        print("Microphone access denied")
                        onStarted?(false)
                        return
                    }
                    self.beginAuthorizedRecording(onStarted: onStarted)
                }
            }
        default:
            print("Microphone access denied")
            onStarted?(false)
        }
    }

    private func beginAuthorizedRecording(onStarted: ((Bool) -> Void)?) {
        guard !isRecording else { onStarted?(false); return }
        if captureSession == nil { setupSession() }

        // A missing/unpluggable device leaves an inputless session that would
        // capture nothing. Rebuild once in case the session is merely stale, and
        // report failure (rather than entering a false "recording" state) if we
        // still have no usable input.
        if captureSession?.inputs.isEmpty != false {
            setupSession()
        }
        guard captureSession?.inputs.isEmpty == false else {
            print("No usable audio input; not starting recording")
            onStarted?(false)
            return
        }

        // 1. Reset flags and stale writer state before any new samples arrive.
        isStopping = false
        shouldDiscardCurrentRecordingOutput = false
        liveWaveSamples = []
        resetMainWriterState()
        // Clear stale pending buffers on the audio queue before new samples can
        // accumulate (the delegate only buffers while isRecording is true, and
        // audioQueue is serial, so this runs first).
        audioQueue.async {
            self.cancelIdleSessionStop()
            self.pendingSampleBuffers.removeAll()
            self.pendingWavePeak = 0
            self.lastLevelPublishUptime = 0
        }
        isRecording = true
        recordingStartTime = Date()

        // 2. Wrap setup in a Task so stopRecording can wait for it.
        // The writer is wired up BEFORE the capture session starts, and any
        // buffers that beat it (prewarmed session already running) are retained
        // in pendingSampleBuffers — so no audio is lost on either path.
        setupTask = Task { @MainActor in
            let url = getRecordingsDirectory().appendingPathComponent(
                "recording-\(Date().timeIntervalSince1970).wav")
            currentFileURL = url

            do {
                assetWriter = try AVAssetWriter(outputURL: url, fileType: .wav)

                // Use standard WAV format compatible with WhisperKit
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16000.0,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]

                assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
                assetWriterInput?.expectsMediaDataInRealTime = true

                if assetWriter?.canAdd(assetWriterInput!) == true {
                    assetWriter?.add(assetWriterInput!)
                }

                assetWriter?.startWriting()
                isSessionStarted = false

                DispatchQueue.main.async {
                    self.audioLevel = 0.0
                    self.audioFrequency = 0.0
                }

                print("Recording started: \(url.lastPathComponent)")

            } catch {
                print("Error starting recording: \(error)")
                isRecording = false  // Revert if failed
                audioQueue.async {
                    self.captureSession?.stopRunning()
                }
                onStarted?(false)
                return
            }

            audioQueue.async {
                if self.captureSession?.isRunning != true {
                    print("🎤 Starting capture session...")
                    self.captureSession?.startRunning()
                }
            }

            // Capture is genuinely underway now (usable input + writer created +
            // session start scheduled) — only here do we tell the caller to
            // enter the recording HUD, so a writer failure above can't leave a
            // false "recording" state on screen.
            onStarted?(true)
        }
    }

    func stopRecording(discardOutput: Bool = false) async -> URL? {
        // Wait for setup to complete if it's running
        _ = await setupTask?.value

        guard isRecording, let url = currentFileURL else { return nil }
        shouldDiscardCurrentRecordingOutput = discardOutput

        // Ensure minimum recording duration to prevent empty/corrupted WAV files
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration < 0.5 {
                try? await Task.sleep(nanoseconds: UInt64((0.5 - duration) * 1_000_000_000))
            }
        }

        // Set stopping flag BEFORE anything else to prevent race conditions
        isStopping = true
        isRecording = false  // Stop capturing new frames immediately
        recordingStartTime = nil
        DispatchQueue.main.async {
            self.audioLevel = 0.0
            self.audioFrequency = 0.0
        }

        return await withCheckedContinuation { continuation in
            audioQueue.async {
                let finishGroup = DispatchGroup()
                var finalizedRecordingURL: URL?
                let discardOutput = self.shouldDiscardCurrentRecordingOutput

                let writer = self.assetWriter
                let writerInput = self.assetWriterInput

                // Flush any buffers the writer never got to see (e.g. a very
                // short recording stopped before the first delegate callback
                // after the writer became ready).
                if let writer, let writerInput, writer.status == .writing,
                    !self.pendingSampleBuffers.isEmpty, !discardOutput
                {
                    if !self.isSessionStarted, let first = self.pendingSampleBuffers.first {
                        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(first))
                        self.isSessionStarted = true
                    }
                    for buffered in self.pendingSampleBuffers
                    where writerInput.isReadyForMoreMediaData {
                        writerInput.append(buffered)
                    }
                }
                self.pendingSampleBuffers.removeAll()
                self.resetMainWriterState()

                if let writer {
                    finishGroup.enter()
                    writerInput?.markAsFinished()
                    writer.finishWriting {
                        self.audioQueue.async {
                            if discardOutput {
                                try? FileManager.default.removeItem(at: url)
                            } else {
                                finalizedRecordingURL = self.validatedAudioFileURL(
                                    at: url,
                                    writer: writer,
                                    label: "Recording"
                                )
                                if let finalizedRecordingURL {
                                    print("Recording finished saving to \(finalizedRecordingURL.path)")
                                } else {
                                    try? FileManager.default.removeItem(at: url)
                                }
                            }
                            finishGroup.leave()
                        }
                    }
                }

                finishGroup.notify(queue: self.audioQueue) {
                    // Keep microphone fully idle outside active recordings.
                    self.cancelIdleSessionStop()
                    self.captureSession?.stopRunning()
                    self.isStopping = false
                    self.shouldDiscardCurrentRecordingOutput = false
                    continuation.resume(returning: finalizedRecordingURL)
                }
            }
        }
    }

    static func recordingsDirectory() -> URL {
        // Use Application Support instead of Documents for app-managed storage
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let recordingsDir =
            appSupport
            .appendingPathComponent("SpeakType")
            .appendingPathComponent("Recordings")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: recordingsDir,
            withIntermediateDirectories: true
        )

        return recordingsDir
    }

    private func getRecordingsDirectory() -> URL {
        Self.recordingsDirectory()
    }

    private func scheduleIdleSessionStop(delay: TimeInterval = 8) {
        cancelIdleSessionStop()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.isRecording, let session = self.captureSession, session.isRunning else {
                return
            }
            print("🎤 Auto-stopping prewarmed session to save resources")
            session.stopRunning()
        }

        idleSessionStopWorkItem = work
        audioQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelIdleSessionStop() {
        idleSessionStopWorkItem?.cancel()
        idleSessionStopWorkItem = nil
    }
}

extension AudioRecordingService: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Only process audio when actually recording (saves CPU)
        guard isRecording else { return }

        processAudioLevel(from: sampleBuffer)

        // Don't append if we're stopping - prevents race condition crash
        guard !isStopping else { return }
        guard let writer = assetWriter, let input = assetWriterInput,
            writer.status == .writing
        else {
            // Writer not wired up yet — retain the audio so the start of the
            // dictation isn't lost; flushed below once the writer is ready.
            pendingSampleBuffers.append(sampleBuffer)
            if pendingSampleBuffers.count > Self.maxPendingSampleBuffers {
                pendingSampleBuffers.removeFirst(
                    pendingSampleBuffers.count - Self.maxPendingSampleBuffers)
            }
            return
        }

        // --- Main writer (full recording) ---
        if !isSessionStarted {
            let firstBuffer = pendingSampleBuffers.first ?? sampleBuffer
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(firstBuffer))
            isSessionStarted = true
        }

        if !pendingSampleBuffers.isEmpty {
            for buffered in pendingSampleBuffers where input.isReadyForMoreMediaData {
                input.append(buffered)
            }
            pendingSampleBuffers.removeAll()
        }

        if input.isReadyForMoreMediaData {
            guard !isStopping else { return }
            input.append(sampleBuffer)
        }
    }

    private func processAudioLevel(from sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else { return }

        var audioBufferListSizeNeeded = 0
        var blockBuffer: CMBlockBuffer?
        let bufferFlags = UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment)

        let sizeQueryStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &audioBufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: bufferFlags,
            blockBufferOut: &blockBuffer
        )

        guard sizeQueryStatus == noErr, audioBufferListSizeNeeded > 0 else { return }

        let audioBufferListStorage = UnsafeMutableRawPointer.allocate(
            byteCount: audioBufferListSizeNeeded,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { audioBufferListStorage.deallocate() }

        let audioBufferList = audioBufferListStorage.assumingMemoryBound(to: AudioBufferList.self)

        let bufferListStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &audioBufferListSizeNeeded,
            bufferListOut: audioBufferList,
            bufferListSize: audioBufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: bufferFlags,
            blockBufferOut: &blockBuffer
        )

        guard bufferListStatus == noErr else { return }

        let audioBuffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let sampleStride = 4
        var sumSquares: Float = 0.0
        var peakLevel: Float = 0.0  // max abs sample — drives the lively waveform
        var processedSampleCount = 0
        var zeroCrossings = 0
        var previousSample: Float?

        for audioBuffer in audioBuffers {
            guard let data = audioBuffer.mData, audioBuffer.mDataByteSize > 0 else { continue }

            if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 {
                let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Float>.size
                guard sampleCount > 0 else { continue }

                let samples = data.assumingMemoryBound(to: Float.self)
                for index in Swift.stride(from: 0, to: sampleCount, by: sampleStride) {
                    let sample = samples[index]
                    let amplitude = abs(sample)
                    sumSquares += sample * sample
                    peakLevel = max(peakLevel, amplitude)
                    if let previousSample,
                        (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0)
                    {
                        zeroCrossings += 1
                    }
                    previousSample = sample
                    processedSampleCount += 1
                }
            } else if asbd.mBitsPerChannel == 16 {
                let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Int16>.size
                guard sampleCount > 0 else { continue }

                let samples = data.assumingMemoryBound(to: Int16.self)
                for index in Swift.stride(from: 0, to: sampleCount, by: sampleStride) {
                    let sample = Float(samples[index]) / Float(Int16.max)
                    let amplitude = abs(sample)
                    sumSquares += sample * sample
                    peakLevel = max(peakLevel, amplitude)
                    if let previousSample,
                        (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0)
                    {
                        zeroCrossings += 1
                    }
                    previousSample = sample
                    processedSampleCount += 1
                }
            } else if asbd.mBitsPerChannel == 32 {
                let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Int32>.size
                guard sampleCount > 0 else { continue }

                let samples = data.assumingMemoryBound(to: Int32.self)
                for index in Swift.stride(from: 0, to: sampleCount, by: sampleStride) {
                    let sample = Float(samples[index]) / Float(Int32.max)
                    let amplitude = abs(sample)
                    sumSquares += sample * sample
                    peakLevel = max(peakLevel, amplitude)
                    if let previousSample,
                        (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0)
                    {
                        zeroCrossings += 1
                    }
                    previousSample = sample
                    processedSampleCount += 1
                }
            }
        }

        guard processedSampleCount > 0 else { return }

        let rms = sqrt(sumSquares / Float(processedSampleCount))

        // Convert to Decibels
        // 20 * log10(rms) gives dB.
        let dB = 20 * log10(rms > 0 ? rms : 0.0001)
        let peakDB = 20 * log10(peakLevel > 0 ? peakLevel : 0.0001)

        // Normalize to 0...1 for UI
        let lowerLimit: Float = -58.0
        let upperLimit: Float = 0.0

        let clamped = max(lowerLimit, min(upperLimit, dB))
        let peakClamped = max(lowerLimit, min(upperLimit, peakDB))

        let normalizedRMS = (clamped - lowerLimit) / (upperLimit - lowerLimit)
        let normalizedPeak = (peakClamped - lowerLimit) / (upperLimit - lowerLimit)
        var normalizedLevel = max(normalizedRMS * 0.8, normalizedPeak)

        if normalizedLevel < 0.015 {
            normalizedLevel = 0
            zeroCrossings = 0
        }

        let zcr = Float(zeroCrossings) / Float(processedSampleCount)
        var normalizedFreq = zcr * 4.0
        normalizedFreq = max(0.0, min(1.0, normalizedFreq))

        let levelSmoothing: Float = normalizedLevel > smoothedAudioLevel ? 0.55 : 0.18
        let frequencySmoothing: Float = normalizedFreq > smoothedAudioFrequency ? 0.45 : 0.2
        smoothedAudioLevel += (normalizedLevel - smoothedAudioLevel) * levelSmoothing
        smoothedAudioFrequency += (normalizedFreq - smoothedAudioFrequency) * frequencySmoothing

        pendingWavePeak = max(pendingWavePeak, min(1.0, peakLevel))

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastLevelPublishUptime >= Self.levelPublishInterval else { return }
        lastLevelPublishUptime = now

        let wavePeak = pendingWavePeak
        pendingWavePeak = 0

        DispatchQueue.main.async {
            self.audioLevel = self.smoothedAudioLevel
            self.audioFrequency = self.smoothedAudioFrequency
            self.liveWaveSamples.append(wavePeak)
            if self.liveWaveSamples.count > Self.maxLiveWaveSamples {
                self.liveWaveSamples.removeFirst(
                    self.liveWaveSamples.count - Self.maxLiveWaveSamples)
            }
        }
    }
}
