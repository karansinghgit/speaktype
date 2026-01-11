import Foundation
import AVFoundation
import Combine

class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService() // Shared instance for settings/dashboard sync

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
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
    private var recordingStartTime: Date?
    private var currentFileURL: URL?
    private var isSessionStarted = false
    
    private let audioQueue = DispatchQueue(label: "com.speaktype.audioQueue")
    
    override init() {
        super.init()
        fetchAvailableDevices()
        if let first = availableDevices.first {
            selectedDeviceId = first.uniqueID
        }
    }
    
    func fetchAvailableDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [AVCaptureDevice.DeviceType.builtInMicrophone, AVCaptureDevice.DeviceType.externalUnknown],
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
    }
    
    func startRecording() {
        requestPermission()
        
        guard !isRecording else { return }
        if captureSession == nil { setupSession() }
        
        let url = getDocumentsDirectory().appendingPathComponent("recording-\(Date().timeIntervalSince1970).wav")
        currentFileURL = url
        
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .wav)
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
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
            
            audioQueue.async {
                self.captureSession?.startRunning()
            }
            
            DispatchQueue.main.async {
                self.audioLevel = 0.0
            }
            
            isRecording = true
            print("Recording started: \(url.lastPathComponent)")
            
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    func stopRecording() async -> URL? {
        guard isRecording, let url = currentFileURL else { return nil }
        
        isRecording = false // Stop capturing new frames immediately
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
        
        return await withCheckedContinuation { continuation in
            audioQueue.async {
                self.captureSession?.stopRunning()
                self.assetWriterInput?.markAsFinished()
                self.assetWriter?.finishWriting {
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
    
    private func getDocumentsDirectory() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "customRecordingPath"), 
           !customPath.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: customPath, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: customPath)
            }
        }
        
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecordingService: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Always process audio level for visualization, regardless of recording status
        processAudioLevel(from: sampleBuffer)
        
        guard isRecording, let writer = assetWriter, let input = assetWriterInput else { return }
        
        if writer.status == .writing {
            if !isSessionStarted {
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                isSessionStarted = true
            }
            
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    private func processAudioLevel(from sampleBuffer: CMSampleBuffer) {
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
        
        // Assuming 16-bit PCM (Int16) as configured in setupSession settings
        let actualData = data.assumingMemoryBound(to: Int16.self)
        let frameCount = Int(audioBufferList.mBuffers.mDataByteSize) / 2 // 2 bytes per sample
        
        var sumSquares: Float = 0.0
        
        // Optimization: Don't check every single sample for visualization purposes
        // Checking every 4th sample is usually sufficient for UI and saves CPU
        let stride = 4
        let samplesToRead = frameCount / stride
        
        for i in 0..<samplesToRead {
            let sample = Float(actualData[i * stride])
            // Normalized sample (-1.0 to 1.0 range based on Int16 max)
            let normalized = sample / 32767.0
            sumSquares += normalized * normalized
        }
        
        let rms = sqrt(sumSquares / Float(samplesToRead))
        
        // Convert to Decibels
        // 20 * log10(rms) gives dB.
        let dB = 20 * log10(rms > 0 ? rms : 0.0001)
        
        // Normalize to 0...1 for UI
        // Raised noise floor to -45.0 dB to ignore ambient noise (fans, AC, etc.)
        let lowerLimit: Float = -45.0
        let upperLimit: Float = 0.0
        
        // Clamp
        let clamped = max(lowerLimit, min(upperLimit, dB))
        
        // Linear mapping
        var normalizedLevel = (clamped - lowerLimit) / (upperLimit - lowerLimit)
        
        // Signal Gate: Force silence if below a low threshold to prevent "nervous" jitter
        if normalizedLevel < 0.05 {
            normalizedLevel = 0
        }
        
        DispatchQueue.main.async {
             self.audioLevel = normalizedLevel
        }
    }
}
