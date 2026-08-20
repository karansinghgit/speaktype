import XCTest
@testable import speaktype

/// Guards the rules that decide whether a model gets warmed up in the
/// background, so the first dictation doesn't pay the model-load cost.
@MainActor
final class TranscriptionWarmUpTests: XCTestCase {

    private var manager: TranscriptionManager { TranscriptionManager.shared }
    private var downloads: ModelDownloadService { ModelDownloadService.shared }

    private let variant = ParakeetCatalog.v2Variant
    private var savedProgress: [String: Double] = [:]

    override func setUp() {
        super.setUp()
        savedProgress = downloads.downloadProgress
    }

    override func tearDown() {
        downloads.downloadProgress = savedProgress
        super.tearDown()
    }

    func testWarmUpIsSkippedForAnEmptyVariant() {
        XCTAssertFalse(manager.warmUp(variant: ""))
        XCTAssertNil(manager.warmingVariant)
    }

    func testWarmUpIsSkippedWhenTheModelIsNotDownloaded() {
        // Loading an absent model falls through to the engine's own download
        // path, which would pull gigabytes with no progress UI. Warm-up must
        // never trigger that.
        downloads.downloadProgress[variant] = 0.0

        XCTAssertFalse(manager.warmUp(variant: variant))
        XCTAssertNil(manager.warmingVariant)
    }

    func testWarmUpIsSkippedForAPartiallyDownloadedModel() {
        downloads.downloadProgress[variant] = 0.87

        XCTAssertFalse(manager.warmUp(variant: variant))
        XCTAssertNil(manager.warmingVariant)
    }

    func testIsDownloadedTracksCompletionOnly() {
        downloads.downloadProgress[variant] = 0.99
        XCTAssertFalse(downloads.isDownloaded(variant))

        downloads.downloadProgress[variant] = 1.0
        XCTAssertTrue(downloads.isDownloaded(variant))

        downloads.downloadProgress.removeValue(forKey: variant)
        XCTAssertFalse(downloads.isDownloaded(variant))
    }
}
