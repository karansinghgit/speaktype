import AVFoundation
import Combine
import CoreMedia
import Foundation

class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()  // Shared instance for settings/dashboard sync

    // Chunk publisher: emits the URL of each completed ~4-second audio chunk while recording
    let chunkPublisher = PassthroughSubject<URL, Never>()
    private static let chunkDuration: TimeInterval = 4.0

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

    // MARK: - Chunking state
    private var chunkAssetWriter: AVAssetWriter?
    private var chunkAssetWriterInput: AVAssetWriterInput?
    private var chunkIsSessionStarted = false
    private var chunkStartTime: Date?
    private var chunkFileURL: URL?
    private var isRotatingChunk = false  // Prevents concurrent rotations
    private var shouldDiscardCurrentRecordingOutput = false
    private var smoothedAudioLevel: Float = 0.0
    private var smoothedAudioFrequency: Float = 0.0

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

    private func resetChunkWriterState() {
        chunkAssetWriter = nil
        chunkAssetWriterInput = nil
        chunkIsSessionStarted = false
        chunkStartTime = nil
        chunkFileURL = nil
        isRotatingChunk = false
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

    func setupSession() {
        captureSession?.stopRunning()
        captureSession = AVCaptureSession()

        guard let deviceId = selectedDeviceId,
            let device = AVCaptureDevice(uniqueID: deviceId),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("Failed to find or add device with ID: \(selectedDeviceId ?? "nil")")
            return
        }

        if captureSession?.canAddInput(input) == true {
            captureSession?.addInput(input)
        }

        audioOutput = AVCaptureAudioDataOutput()
        if captureSession?.canAddOutput(audioOutput!) == true {
            captureSession?.addOutput(audioOutput!)
            audioOutput?.setSampleBufferDelegate(self, queue: audioQueue)
        }

        // Don't start session here - only start when recording begins
        // This prevents continuous CPU usage when idle
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

    func startRecording() {
        requestPermission()

        guard !isRecording else { return }
        if captureSession == nil { setupSession() }

        // 1. Reset flags and stale writer state before any new samples arrive.
        isStopping = false
        shouldDiscardCurrentRecordingOutput = false
        liveWaveSamples = []
        resetMainWriterState()
        resetChunkWriterState()
        isRecording = true
        // Hop onto audioQueue: idleSessionStopWorkItem is only ever touched there,
        // and startRecording runs on the main thread.
        audioQueue.async { self.cancelIdleSessionStop() }

        // 2. Wrap setup in a Task so stopRecording can wait for it
        setupTask = Task { @MainActor in
            // Ensure capture session is running before setting up the writer
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                audioQueue.async {
                    if self.captureSession?.isRunning != true {
                        print("🎤 Starting capture session...")
                        self.captureSession?.startRunning()
                        // Wait for session to be ready
                        Thread.sleep(forTimeInterval: 0.3)
                        print("🎤 Capture session started")
                    }
                    continuation.resume()
                }
            }

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
            }
        }
    }

    func stopRecording(discardOutput: Bool = false) async -> URL? {
        // Wait for setup to complete if it's running
        _ = await setupTask?.value

        guard isRecording, let url = currentFileURL else { return nil }
        shouldDiscardCurrentRecordingOutput = discardOutput

        // Ensure minimum recording duration to prevent empty/corrupted WAV files
        if let startTime = currentFileURL?.path.components(separatedBy: "-").last?
            .replacingOccurrences(of: ".wav", with: ""),
            let startTimestamp = Double(startTime)
        {
            let duration = Date().timeIntervalSince1970 - startTimestamp
            if duration < 0.5 {
                try? await Task.sleep(nanoseconds: UInt64((0.5 - duration) * 1_000_000_000))
            }
        }

        // Set stopping flag BEFORE anything else to prevent race conditions
        isStopping = true
        isRecording = false  // Stop capturing new frames immediately
        DispatchQueue.main.async {
            self.audioLevel = 0.0
            self.audioFrequency = 0.0
        }

        return await withCheckedContinuation { continuation in
            audioQueue.async {
                // --- Finalize the last in-flight chunk ---
                let finishGroup = DispatchGroup()
                var finalizedRecordingURL: URL?
                let discardOutput = self.shouldDiscardCurrentRecordingOutput

                if let lastChunkInput = self.chunkAssetWriterInput,
                    let lastChunkWriter = self.chunkAssetWriter,
                    let lastChunkURL = self.chunkFileURL,
                    self.chunkIsSessionStarted
                {
                    self.resetChunkWriterState()

                    finishGroup.enter()
                    lastChunkInput.markAsFinished()
                    lastChunkWriter.finishWriting {
                        self.audioQueue.async {
                            if discardOutput {
                                try? FileManager.default.removeItem(at: lastChunkURL)
                            } else if let validChunkURL = self.validatedAudioFileURL(
                                at: lastChunkURL,
                                writer: lastChunkWriter,
                                label: "Final chunk"
                            ) {
                                print("🔪 Final chunk saved: \(validChunkURL.lastPathComponent)")
                                self.chunkPublisher.send(validChunkURL)
                            } else {
                                try? FileManager.default.removeItem(at: lastChunkURL)
                            }
                            finishGroup.leave()
                        }
                    }
                }

                // --- Finalize main (full) recording ---
                let writer = self.assetWriter
                let writerInput = self.assetWriterInput
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

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default:
            print("Microphone access denied")
        }
    }

    private func getRecordingsDirectory() -> URL {
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

    private func getChunksDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let chunksDir =
            appSupport
            .appendingPathComponent("SpeakType")
            .appendingPathComponent("Chunks")

        try? FileManager.default.createDirectory(
            at: chunksDir,
            withIntermediateDirectories: true
        )

        return chunksDir
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
        guard let writer = assetWriter, let input = assetWriterInput else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // --- Main writer (full recording) ---
        if writer.status == .writing {
            if !isSessionStarted {
                writer.startSession(atSourceTime: pts)
                isSessionStarted = true
            }

            if input.isReadyForMoreMediaData {
                guard !isStopping else { return }
                input.append(sampleBuffer)
            }
        }

        // --- Chunk writer (background segments) ---
        appendToChunk(sampleBuffer: sampleBuffer, pts: pts)
    }

    // MARK: - Chunk Writer Helpers (audioQueue)

    private func appendToChunk(sampleBuffer: CMSampleBuffer, pts: CMTime) {
        guard !isStopping else { return }

        // Initialize first chunk on first buffer
        if chunkAssetWriter == nil {
            startNewChunkWriter(startingAt: pts)
        }

        guard let cw = chunkAssetWriter, let ci = chunkAssetWriterInput,
            cw.status == .writing
        else { return }

        if !chunkIsSessionStarted {
            cw.startSession(atSourceTime: pts)
            chunkIsSessionStarted = true
            chunkStartTime = Date()
        }

        if ci.isReadyForMoreMediaData {
            guard !isStopping else { return }
            ci.append(sampleBuffer)
        }

        // Rotate chunk after chunkDuration seconds
        guard !isRotatingChunk,
            let start = chunkStartTime,
            Date().timeIntervalSince(start) >= Self.chunkDuration
        else { return }

        rotateChunk(nextStartPTS: pts)
    }

    private func startNewChunkWriter(startingAt pts: CMTime) {
        let url = getChunksDirectory().appendingPathComponent(
            "chunk-\(Date().timeIntervalSince1970).wav")
        chunkFileURL = url

        guard let cw = try? AVAssetWriter(outputURL: url, fileType: .wav) else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let ci = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        ci.expectsMediaDataInRealTime = true

        if cw.canAdd(ci) { cw.add(ci) }
        cw.startWriting()

        chunkAssetWriter = cw
        chunkAssetWriterInput = ci
        chunkIsSessionStarted = false
    }

    private func rotateChunk(nextStartPTS: CMTime) {
        isRotatingChunk = true

        guard let oldWriter = chunkAssetWriter,
            let oldInput = chunkAssetWriterInput,
            let finishedURL = chunkFileURL
        else {
            isRotatingChunk = false
            return
        }

        // Detach before finishing so new samples go to the fresh writer
        chunkAssetWriter = nil
        chunkAssetWriterInput = nil
        chunkIsSessionStarted = false
        chunkStartTime = nil
        chunkFileURL = nil

        // Spin up the next chunk immediately so no audio is lost
        startNewChunkWriter(startingAt: nextStartPTS)
        isRotatingChunk = false

        // Finish the old writer asynchronously
        oldInput.markAsFinished()
        oldWriter.finishWriting { [weak self] in
            guard let self = self else { return }
            if self.shouldDiscardCurrentRecordingOutput {
                try? FileManager.default.removeItem(at: finishedURL)
            } else {
                print("🔪 Chunk saved: \(finishedURL.lastPathComponent)")
                self.chunkPublisher.send(finishedURL)
            }
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

        DispatchQueue.main.async {
            self.audioLevel = self.smoothedAudioLevel
            self.audioFrequency = self.smoothedAudioFrequency
            self.liveWaveSamples.append(min(1.0, peakLevel))
            if self.liveWaveSamples.count > Self.maxLiveWaveSamples {
                self.liveWaveSamples.removeFirst(
                    self.liveWaveSamples.count - Self.maxLiveWaveSamples)
            }
        }
    }
}
