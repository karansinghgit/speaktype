import Foundation
import AVFoundation
import Combine
import CoreMedia
class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService() // Shared instance for settings/dashboard sync

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var audioFrequency: Float = 0.0 // Normalized 0...1 representation of pitch
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceId: String? {
        didSet {
            setupSession()
        }
    }
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    public private(set) var recordingStartTime: Date?
    private var currentFileURL: URL?
    private var isSessionStarted = false
    private var setupTask: Task<Void, Never>?
    private var isStopping = false // Flag to prevent appending during stop
    
    private let audioQueue = DispatchQueue(label: "com.speaktype.audioQueue")
    
    override init() {
        super.init()
        fetchAvailableDevices()
        if let first = availableDevices.first {
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
            if self.selectedDeviceId == nil, let first = self.availableDevices.first {
                self.selectedDeviceId = first.uniqueID
            }
        }
    }
    
    func setupSession() {
        captureSession?.stopRunning()
        captureSession = AVCaptureSession()
        
        guard let deviceId = selectedDeviceId,
              let device = AVCaptureDevice(uniqueID: deviceId),
              let input = try? AVCaptureDeviceInput(device: device) else {
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
        }
    }
    
    func startRecording() {
        requestPermission()
        
        guard !isRecording else { return }
        if captureSession == nil { setupSession() }
        
        // 1. Reset flags and set Recording State Immediately
        isStopping = false
        isRecording = true
        
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
            
            let url = getRecordingsDirectory().appendingPathComponent("recording-\(Date().timeIntervalSince1970).wav")
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
                    AVLinearPCMIsNonInterleaved: false
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
                isRecording = false // Revert if failed
            }
        }
    }
    
    func stopRecording() async -> URL? {
        // Wait for setup to complete if it's running
        _ = await setupTask?.value
        
        guard isRecording, let url = currentFileURL else { return nil }
        
        // Set stopping flag BEFORE anything else to prevent race conditions
        isStopping = true
        isRecording = false // Stop capturing new frames immediately
        DispatchQueue.main.async {
            self.audioLevel = 0.0
            self.audioFrequency = 0.0
        }
        
        return await withCheckedContinuation { continuation in
            audioQueue.async {
                // Stop the capture session first to prevent more audio data
                self.captureSession?.stopRunning()
                
                // Small delay to let any in-flight audio data finish
                Thread.sleep(forTimeInterval: 0.05)
                
                self.assetWriterInput?.markAsFinished()
                self.assetWriter?.finishWriting {
                    self.isStopping = false // Reset flag after writing is complete
                    print("Recording finished saving to \(url.path)")
                    continuation.resume(returning: url)
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
        
        let recordingsDir = appSupport
            .appendingPathComponent("SpeakType")
            .appendingPathComponent("Recordings")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: recordingsDir,
            withIntermediateDirectories: true
        )
        
        return recordingsDir
    }
}

extension AudioRecordingService: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Only process audio when actually recording (saves CPU)
        guard isRecording else { return }
        
        processAudioLevel(from: sampleBuffer)
        
        // Don't append if we're stopping - prevents race condition crash
        guard !isStopping else { return }
        guard let writer = assetWriter, let input = assetWriterInput else { return }
        
        if writer.status == .writing {
            if !isSessionStarted {
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                isSessionStarted = true
            }
            
            if input.isReadyForMoreMediaData {
                // Double-check we're not stopping before appending
                guard !isStopping else { return }
                input.append(sampleBuffer)
            }
        }
    }
    
    private func processAudioLevel(from sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return }

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard let data = audioBufferList.mBuffers.mData else { return }
        
        // Safety check for bytes per frame
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return }
        
        let frameCount = Int(audioBufferList.mBuffers.mDataByteSize) / bytesPerFrame
        let stride = 4
        let samplesToRead = frameCount / stride
        
        guard samplesToRead > 0 else { return }
        
        var sumSquares: Float = 0.0
        var zeroCrossings: Int = 0
        var previousSample: Float = 0.0
        
        if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 {
            // Float32 Processing (Standard on Mac)
            let actualData = data.assumingMemoryBound(to: Float.self)
            previousSample = actualData[0]
            
            for i in 0..<samplesToRead {
                let sample = actualData[i * stride]
                sumSquares += sample * sample
                
                // Zero Crossing Check
                if (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0) {
                    zeroCrossings += 1
                }
                previousSample = sample
            }
        } else {
            // Int16 Processing (Fallback)
            if asbd.mBitsPerChannel == 16 {
                let actualData = data.assumingMemoryBound(to: Int16.self)
                previousSample = Float(actualData[0])
                
                for i in 0..<samplesToRead {
                    let sample = Float(actualData[i * stride]) / 32768.0
                    sumSquares += sample * sample
                    
                    if (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0) {
                        zeroCrossings += 1
                    }
                    previousSample = sample
                }
            } else if asbd.mBitsPerChannel == 32 {
                 // Int32 Processing
                 let actualData = data.assumingMemoryBound(to: Int32.self)
                 previousSample = Float(actualData[0])
                 
                 for i in 0..<samplesToRead {
                     let sample = Float(actualData[i * stride]) / 2147483648.0
                     sumSquares += sample * sample
                     
                     if (previousSample > 0 && sample <= 0) || (previousSample <= 0 && sample > 0) {
                         zeroCrossings += 1
                     }
                     previousSample = sample
                 }
            }
        }
        
        let rms = sqrt(sumSquares / Float(samplesToRead))
        
        // Convert to Decibels
        // 20 * log10(rms) gives dB.
        let dB = 20 * log10(rms > 0 ? rms : 0.0001)
        
        // Normalize to 0...1 for UI
        // Tuned to -50.0 dB for smoother response (less jittery than -60)
        let lowerLimit: Float = -50.0
        let upperLimit: Float = 0.0
        
        // Clamp
        let clamped = max(lowerLimit, min(upperLimit, dB))
        
        // Linear mapping
        var normalizedLevel = (clamped - lowerLimit) / (upperLimit - lowerLimit)
        
        // Signal Gate: Minimal gate to avoid absolute zero, but allow quiet sounds
        if normalizedLevel < 0.01 {
            normalizedLevel = 0
            zeroCrossings = 0
        }
        
        // Calculate approximate frequency from ZCR
        // Frequency = (Zero Crossings * Sample Rate) / (2 * N)
        // Note: 'stride' reduces effective sample rate for this calculation, so we adjust
        let effectiveSampleRate = Float(asbd.mSampleRate) / Float(stride)
        let _ = (Float(zeroCrossings) * effectiveSampleRate) / (2.0 * Float(samplesToRead))
        
        // Normalize Frequency for UI (0...1)
        // Human voice fundamental freq is roughly 85Hz - 255Hz, harmonics go higher.
        // Let's map 0-3000Hz (speech range) to 0-1 for visualization
        // But ZCR is noisy, so we just want "more zcr" = "higher pitch"
        // Let's just normalize ZCR relative to the number of samples
        let zcr = Float(zeroCrossings) / Float(samplesToRead)
        
        // Empirically, ZCR for speech varies. Let's amplify likely speech range.
        var normalizedFreq = zcr * 5.0 // Gain to make changes visible
        normalizedFreq = max(0.0, min(1.0, normalizedFreq))
        
        DispatchQueue.main.async {
             self.audioLevel = normalizedLevel
             self.audioFrequency = normalizedFreq
        }
    }
}
