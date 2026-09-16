import XCTest
@testable import speaktype

final class RecordingMediaCoordinatorTests: XCTestCase {
    func testPlayingMediaPausesAndResumes() throws {
        let mediaController = MockSystemMediaController(isPlaying: true)
        let coordinator = RecordingMediaCoordinator(mediaController: mediaController)

        coordinator.recordingWillStart()

        XCTAssertEqual(mediaController.pauseIfPlayingCallCount, 1)
        XCTAssertTrue(mediaController.isPaused)
        XCTAssertTrue(coordinator.hasPausedMediaForCurrentRecording)

        coordinator.recordingDidFinish()

        XCTAssertEqual(mediaController.resumeCallCount, 1)
        XCTAssertFalse(mediaController.isPaused)
        XCTAssertFalse(coordinator.hasPausedMediaForCurrentRecording)
    }

    func testPausedMediaIsNotResumed() throws {
        let mediaController = MockSystemMediaController(isPlaying: false)
        let coordinator = RecordingMediaCoordinator(mediaController: mediaController)

        coordinator.recordingWillStart()
        coordinator.recordingDidFinish()

        XCTAssertEqual(mediaController.pauseIfPlayingCallCount, 1)
        XCTAssertEqual(mediaController.resumeCallCount, 0)
        XCTAssertFalse(coordinator.hasPausedMediaForCurrentRecording)
    }

    func testMediaControlFailureDoesNotTrackPausedMedia() throws {
        let mediaController = MockSystemMediaController(isPlaying: true)
        mediaController.pauseError = SystemMediaControlError.playbackStateUnavailable
        let coordinator = RecordingMediaCoordinator(mediaController: mediaController)

        coordinator.recordingWillStart()
        coordinator.recordingDidFinish()

        XCTAssertEqual(mediaController.pauseIfPlayingCallCount, 1)
        XCTAssertEqual(mediaController.resumeCallCount, 0)
        XCTAssertFalse(coordinator.hasPausedMediaForCurrentRecording)
    }

    func testRecordingFailureAfterPauseRestoresMedia() throws {
        let mediaController = MockSystemMediaController(isPlaying: true)
        let coordinator = RecordingMediaCoordinator(mediaController: mediaController)

        coordinator.recordingWillStart()
        coordinator.recordingDidFinish()

        XCTAssertEqual(mediaController.resumeCallCount, 1)
        XCTAssertFalse(mediaController.isPaused)
        XCTAssertFalse(coordinator.hasPausedMediaForCurrentRecording)
    }

    func testRepeatedCleanupOnlyResumesOnce() throws {
        let mediaController = MockSystemMediaController(isPlaying: true)
        let coordinator = RecordingMediaCoordinator(mediaController: mediaController)

        coordinator.recordingWillStart()
        coordinator.recordingDidFinish()
        coordinator.recordingDidFinish()

        XCTAssertEqual(mediaController.resumeCallCount, 1)
        XCTAssertFalse(coordinator.hasPausedMediaForCurrentRecording)
    }
}

private final class MockSystemMediaController: SystemMediaControlling {
    var isPlaying: Bool
    var isPaused = false
    var pauseError: Error?
    var resumeError: Error?
    var pauseIfPlayingCallCount = 0
    var resumeCallCount = 0

    init(isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    func pauseIfPlaying() throws -> Bool {
        pauseIfPlayingCallCount += 1

        if let pauseError {
            throw pauseError
        }

        guard isPlaying else { return false }

        isPlaying = false
        isPaused = true
        return true
    }

    func resume() throws {
        resumeCallCount += 1

        if let resumeError {
            throw resumeError
        }

        isPlaying = true
        isPaused = false
    }
}
