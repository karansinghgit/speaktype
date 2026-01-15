import Foundation
import AVFoundation
import Combine

/// Service for playing back audio recordings
class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerService()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentAudioURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    private override init() {
        super.init()
    }
    
    /// Load audio file and prepare for playback
    func loadAudio(from url: URL) {
        do {
            // Reset previous state
            stop()
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentAudioURL = url
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    /// Seek to specific time in the audio
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }
    
    /// Reset player completely
    func reset() {
        stop()
        audioPlayer = nil
        currentAudioURL = nil
        duration = 0
        currentTime = 0
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
        player.currentTime = 0
    }
}
