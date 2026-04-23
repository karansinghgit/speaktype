import XCTest
@testable import speaktype

final class ModelDownloadServiceTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }
    
    func testInitialState() {
        let service = ModelDownloadService.shared
        
        // Ensure no lingering downloads from other runs
        // (Note: Shared singleton might have state if tests run in parallel or sequence without clearing)
        // We can't easily clear private vars, but we can check types.
        
        XCTAssertNotNil(service.downloadProgress)
        XCTAssertNotNil(service.isDownloading)
    }

    func testCandidatePathsStayWithinRepoOwnedRoots() throws {
        let locations = makeLocations()
        let variant = "openai_whisper-medium"

        let directPath = try createDirectory(
            at: locations.documentsDirectory!
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(variant)")
        )
        let hubPath = try createDirectory(
            at: locations.cachesDirectory!
                .appendingPathComponent(
                    "huggingface/hub/models--argmaxinc--whisperkit-coreml/snapshots/123/\(variant)"
                )
        )
        _ = try createDirectory(at: locations.documentsDirectory!.appendingPathComponent(variant))
        _ = try createDirectory(
            at: locations.documentsDirectory!
                .appendingPathComponent("huggingface/models/random-repo/\(variant)")
        )

        let candidatePaths = ModelCachePathResolver.candidatePaths(
            for: variant,
            locations: locations
        )
        let normalizedCandidatePaths = Set(candidatePaths.map(normalizedPath))

        XCTAssertTrue(normalizedCandidatePaths.contains(normalizedPath(directPath)))
        XCTAssertTrue(normalizedCandidatePaths.contains(normalizedPath(hubPath)))
        XCTAssertFalse(
            normalizedCandidatePaths.contains(
                normalizedPath(locations.documentsDirectory!.appendingPathComponent(variant))
            )
        )
        XCTAssertFalse(
            normalizedCandidatePaths.contains(
                normalizedPath(
                    locations.documentsDirectory!
                        .appendingPathComponent("huggingface/models/random-repo/\(variant)")
                )
            )
        )
    }

    func testRemoveVariantDirectoriesOnlyDeletesExactRepoOwnedMatches() throws {
        let locations = makeLocations()
        let variant = "openai_whisper-medium"

        let directPath = try createDirectory(
            at: locations.documentsDirectory!
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(variant)")
        )
        let hubPath = try createDirectory(
            at: locations.cachesDirectory!
                .appendingPathComponent(
                    "huggingface/hub/models--argmaxinc--whisperkit-coreml/snapshots/abc123/\(variant)"
                )
        )
        let backupPath = try createDirectory(
            at: locations.documentsDirectory!
                .appendingPathComponent(
                    "huggingface/models/argmaxinc/whisperkit-coreml/\(variant)-backup"
                )
        )
        let unrelatedPath = try createDirectory(
            at: locations.documentsDirectory!.appendingPathComponent("\(variant)-notes")
        )

        let report = ModelCachePathResolver.removeVariantDirectories(
            for: variant,
            locations: locations
        )

        XCTAssertEqual(
            Set(report.deletedPaths.map(normalizedPath)),
            Set([directPath, hubPath].map(normalizedPath))
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: directPath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: hubPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedPath.path))
    }

    private func makeLocations() -> ModelCacheLocations {
        let documents = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        let appSupport = tempRoot.appendingPathComponent("Application Support", isDirectory: true)
        let caches = tempRoot.appendingPathComponent("Caches", isDirectory: true)
        let home = tempRoot.appendingPathComponent("Home", isDirectory: true)
        let temp = tempRoot.appendingPathComponent("Temp", isDirectory: true)

        return ModelCacheLocations(
            documentsDirectory: documents,
            applicationSupportDirectory: appSupport,
            cachesDirectory: caches,
            homeDirectory: home,
            temporaryDirectory: temp
        )
    }

    @discardableResult
    private func createDirectory(at url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path.hasPrefix("/private/var/") {
            return path.replacingOccurrences(
                of: "/private/var/",
                with: "/var/",
                options: [.anchored]
            )
        }
        return path
    }
}
