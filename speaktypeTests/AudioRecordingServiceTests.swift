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

    func testSelectedDeviceNameFallback() {
        XCTAssertFalse(service.selectedDeviceName.isEmpty)
    }

    func testCycleDeviceDoesNotCrashWithSingleOrNoDevices() {
        let initialDeviceId = service.selectedDeviceId
        if service.availableDevices.count <= 1 {
            service.cycleDevice(step: 1)
            XCTAssertEqual(service.selectedDeviceId, initialDeviceId)
        }
    }

    func testNextCycledDeviceIdWrapAroundAndEdgeCases() {
        // Empty devices
        XCTAssertNil(
            AudioRecordingService.nextCycledDeviceId(from: [], currentDeviceId: nil, step: 1)
        )

        // Single device stays on same device
        XCTAssertEqual(
            AudioRecordingService.nextCycledDeviceId(
                from: ["mic-1"], currentDeviceId: "mic-1", step: 1),
            "mic-1"
        )

        // Two devices toggle back and forth
        let twoDevices = ["built-in-mic", "external-usb-mic"]
        XCTAssertEqual(
            AudioRecordingService.nextCycledDeviceId(
                from: twoDevices, currentDeviceId: "built-in-mic", step: 1),
            "external-usb-mic"
        )
        XCTAssertEqual(
            AudioRecordingService.nextCycledDeviceId(
                from: twoDevices, currentDeviceId: "external-usb-mic", step: 1),
            "built-in-mic"
        )

        // Three devices forward and backward wrap-around
        let threeDevices = ["mic-1", "mic-2", "mic-3"]
        XCTAssertEqual(
            AudioRecordingService.nextCycledDeviceId(
                from: threeDevices, currentDeviceId: "mic-1", step: -1),
            "mic-3"
        )
        XCTAssertEqual(
            AudioRecordingService.nextCycledDeviceId(
                from: threeDevices, currentDeviceId: "mic-3", step: 1),
            "mic-1"
        )
    }

    // Note: Testing startRecording requires AVFoundation mocking or integration tests
    // due to hardware dependencies.
}
