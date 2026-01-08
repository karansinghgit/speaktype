import Foundation
import AVFoundation
import Combine

class AudioRecordingService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    // Request microphone permission
    func requestPermission() {
        // Just triggered on load if needed, but startRecording handles the check too
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    // Start recording audio
    func startRecording() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.startRecordingInternal()
                    }
                } else {
                    print("Microphone permission denied")
                }
            }
            return
        }
        
        if status == .denied || status == .restricted {
            print("Microphone permission previously denied")
            return
        }
        
        startRecordingInternal()
    }
    
    private func startRecordingInternal() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true // Enable metering
            audioRecorder?.record()
            isRecording = true
            startMetering() // Start timer
            print("Recording started to \(audioFilename)")
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
        }
    }
    
    private func startMetering() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160 to 0 dB
            // Normalize: -60dB to 0dB -> 0.0 to 1.0
            let normalized = max(0.0, (power + 60) / 60)
            DispatchQueue.main.async {
                self.audioLevel = normalized
            }
        }
    }
    
    private func stopMetering() {
        timer?.invalidate()
        timer = nil
        audioLevel = 0.0
    }
    
    // Stop recording and return the file URL
    func stopRecording() -> URL? {
        stopMetering()
        audioRecorder?.stop()
        isRecording = false
        print("Recording stopped")
        return audioRecorder?.url
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
