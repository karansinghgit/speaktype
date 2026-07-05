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

    func testRecorderSourceDoesNotCreateBackgroundChunkFiles() throws {
        let source = try repositorySourceFile("speaktype/Services/AudioRecordingService.swift")

        XCTAssertFalse(source.contains("getChunksDirectory"))
        XCTAssertFalse(source.contains("chunkPublisher"))
        XCTAssertFalse(source.contains("chunkAssetWriter"))
        XCTAssertFalse(source.contains("SpeakType\").appendingPathComponent(\"Chunks"))
    }
    
    // Note: Testing startRecording requires AVFoundation mocking or integration tests
    // due to hardware dependencies.

    private func repositorySourceFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
