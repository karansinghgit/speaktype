import Foundation

final class RecordingMediaCoordinator {
    private let mediaController: SystemMediaControlling?
    private var mediaWasPausedBySpeakType = false

    init(mediaController: SystemMediaControlling? = MediaRemoteMediaController()) {
        self.mediaController = mediaController
    }

    var hasPausedMediaForCurrentRecording: Bool {
        mediaWasPausedBySpeakType
    }

    func recordingWillStart() {
        guard !mediaWasPausedBySpeakType, let mediaController else { return }

        do {
            mediaWasPausedBySpeakType = try mediaController.pauseIfPlaying()
            if mediaWasPausedBySpeakType {
                AppLogger.debug("Paused active system media for recording", category: AppLogger.audio)
            }
        } catch {
            AppLogger.warning(
                "Unable to determine or pause media playback; continuing with recording",
                category: AppLogger.audio
            )
        }
    }

    func recordingDidFinish() {
        guard mediaWasPausedBySpeakType, let mediaController else {
            mediaWasPausedBySpeakType = false
            return
        }

        mediaWasPausedBySpeakType = false

        do {
            try mediaController.resume()
            AppLogger.debug("Resumed system media after recording", category: AppLogger.audio)
        } catch {
            AppLogger.warning(
                "Unable to resume media playback after recording",
                category: AppLogger.audio
            )
        }
    }
}
