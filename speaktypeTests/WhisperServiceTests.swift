import XCTest
@testable import speaktype

@MainActor
final class WhisperServiceTests: XCTestCase {
    
    var service: WhisperService?
    
    override func setUpWithError() throws {
        service = WhisperService()
    }

    override func tearDownWithError() throws {
        // Rely on automatic deallocation
    }

    func testDefaultInitialization() {
        guard let service = service else { return XCTFail("Service should be initialized") }
        XCTAssertFalse(service.isInitialized)
        XCTAssertEqual(service.currentModelVariant, "")
    }
    
    // Note: detailed loadModel tests require mocking the WhisperKit dependency
    // which is external. We test the state management around it.
    
    func testStateFlags() {
        guard let service = service else { return XCTFail("Service should be initialized") }
        XCTAssertFalse(service.isTranscribing)
        // Simulate transcription start
        service.isTranscribing = true
        XCTAssertTrue(service.isTranscribing)
    }

    func testLoadModelRejectsUnknownVariantBeforePathResolution() async {
        guard let service = service else { return XCTFail("Service should be initialized") }

        do {
            try await service.loadModel(variant: "../../outside-model")
            XCTFail("Expected unknown model variant to be rejected")
        } catch WhisperService.TranscriptionError.unsupportedModelVariant {
            // Expected.
        } catch {
            XCTFail("Expected unsupportedModelVariant, got \(error)")
        }
    }

    func testNormalizedTranscriptionRemovesBlankAudioPlaceholders() {
        let normalized = WhisperService.normalizedTranscription(
            from: " [BLANK_AUDIO]  hello   <|nospeech|> [SILENCE] "
        )

        XCTAssertEqual(normalized, "hello")
    }

    func testNormalizedTranscriptionRemovesBracketedNoiseLabels() {
        let normalized = WhisperService.normalizedTranscription(
            from: "[wind blowing] (heartbeat) answer [S]"
        )

        XCTAssertEqual(normalized, "answer")
    }

    func testNormalizedTranscriptionRemovesNoiseOnlyArtifacts() {
        let normalized = WhisperService.normalizedTranscription(
            from: "[wind] (Loud noise) (indistinct)"
        )

        XCTAssertEqual(normalized, "")
    }

    func testTranscriptionServicesDoNotLogTranscriptPrefixes() throws {
        let whisperSource = try repositorySourceFile("speaktype/Services/WhisperService.swift")
        let miniRecorderSource = try repositorySourceFile(
            "speaktype/Views/Overlays/MiniRecorderView.swift")

        XCTAssertFalse(whisperSource.contains("text.prefix"))
        XCTAssertFalse(whisperSource.contains("Transcription complete:"))
        XCTAssertFalse(whisperSource.contains("Chunk done:"))
        XCTAssertFalse(miniRecorderSource.contains("/tmp/speaktype_debug.log"))
        XCTAssertFalse(miniRecorderSource.contains("text.prefix"))
        XCTAssertFalse(miniRecorderSource.contains("Transcription result"))
    }

    private func repositorySourceFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
