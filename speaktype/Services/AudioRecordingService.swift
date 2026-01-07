import Foundation
import AVFoundation
import Combine

class AudioRecordingService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    
    // Request microphone permission
    func requestPermission() {
        // Just triggered on load if needed, but startRecording handles the check too
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    // Start recording audio to a temporary file
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
            audioRecorder?.record()
            isRecording = true
            print("Recording started to \(audioFilename)")
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
        }
    }
    
    // Stop recording and return the file URL
    func stopRecording() -> URL? {
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
