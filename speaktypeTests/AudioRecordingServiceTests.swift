import XCTest
@testable import speaktype

final class AudioRecordingServiceTests: XCTestCase {
    
    var service: AudioRecordingService!
    
    override func setUpWithError() throws {
        service = AudioRecordingService()
    }

    override func tearDownWithError() throws {
        service = nil
    }

    func testInitialization() {
        XCTAssertNotNil(service)
        XCTAssertFalse(service.isRecording)
        XCTAssertEqual(service.audioLevel, 0.0)
    }
    
    func testStopRecordingWhenNotRecording() async {
        let url = await service.stopRecording()
        XCTAssertNil(url, "Should return nil url when not recording")
    }
    
    /// A device change (AirPods disconnecting, a USB mic unplugged) calls
    /// `setupSession()` via `selectedDeviceId.didSet`, which can land mid-dictation.
    /// Tearing the session down there strands the in-flight recording and blocks the
    /// caller inside `AVCaptureSession.stopRunning()`, so the rebuild must be deferred.
    func testSessionRebuildIsDeferredWhileRecording() {
        service.isRecording = true
        defer { service.isRecording = false }

        service.setupSession()

        XCTAssertTrue(
            service.needsSessionRebuild,
            "Session rebuild must be deferred while a recording is in flight"
        )
    }

    func testSessionRebuildIsNotDeferredWhenIdle() {
        service.isRecording = false

        service.setupSession()

        XCTAssertFalse(
            service.needsSessionRebuild,
            "An idle session rebuild should be applied immediately, not queued"
        )
    }

    /// `stopRecording()` has been observed never returning, because the asset
    /// writers' `finishWriting` completion handlers never fired and the
    /// `DispatchGroup` gating the stop never reached zero. It must always return,
    /// even when finalization stalls.
    func testStopRecordingAlwaysReturns() async {
        let finished = expectation(description: "stopRecording returned")

        Task {
            _ = await service.stopRecording()
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 15)
    }

    // Note: Testing startRecording requires AVFoundation mocking or integration tests
    // due to hardware dependencies.
}
