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
        // Simulate the two repo-owned WhisperKit model roots (current App Support +
        // legacy Documents), matching ModelStorage's `.../models/argmaxinc/whisperkit-coreml`.
        let currentRoot = try createDirectory(
            at: tempRoot.appendingPathComponent(
                "AppSupport/SpeakType/models/argmaxinc/whisperkit-coreml"))
        let legacyRoot = try createDirectory(
            at: tempRoot.appendingPathComponent(
                "Documents/huggingface/models/argmaxinc/whisperkit-coreml"))
        let roots = [currentRoot, legacyRoot]
        let variant = "openai_whisper-medium"

        let directPath = try createDirectory(at: currentRoot.appendingPathComponent(variant))
        // A hub-style nested layout under a repo-owned root should still be found by
        // exact-name matching.
        let nestedPath = try createDirectory(
            at: legacyRoot.appendingPathComponent("snapshots/123/\(variant)"))
        // A directory that only *contains* the variant name must NOT be a candidate.
        _ = try createDirectory(at: currentRoot.appendingPathComponent("\(variant)-backup"))
        // A model outside any repo-owned root must NOT be a candidate.
        _ = try createDirectory(at: tempRoot.appendingPathComponent(variant))

        let candidatePaths = ModelCachePathResolver.candidatePaths(
            for: variant,
            roots: roots
        )
        let normalizedCandidatePaths = Set(candidatePaths.map(normalizedPath))

        XCTAssertTrue(normalizedCandidatePaths.contains(normalizedPath(directPath)))
        XCTAssertTrue(normalizedCandidatePaths.contains(normalizedPath(nestedPath)))
        XCTAssertFalse(
            normalizedCandidatePaths.contains(
                normalizedPath(currentRoot.appendingPathComponent("\(variant)-backup"))
            )
        )
        XCTAssertFalse(
            normalizedCandidatePaths.contains(
                normalizedPath(tempRoot.appendingPathComponent(variant))
            )
        )
    }

    func testRemoveVariantDirectoriesOnlyDeletesExactRepoOwnedMatches() throws {
        let currentRoot = try createDirectory(
            at: tempRoot.appendingPathComponent(
                "AppSupport/SpeakType/models/argmaxinc/whisperkit-coreml"))
        let legacyRoot = try createDirectory(
            at: tempRoot.appendingPathComponent(
                "Documents/huggingface/models/argmaxinc/whisperkit-coreml"))
        let roots = [currentRoot, legacyRoot]
        let variant = "openai_whisper-medium"

        let directPath = try createDirectory(at: currentRoot.appendingPathComponent(variant))
        let nestedPath = try createDirectory(
            at: legacyRoot.appendingPathComponent("snapshots/abc123/\(variant)"))
        // "<variant>-backup" lives inside a repo-owned root but its name only contains
        // the variant — it must survive.
        let backupPath = try createDirectory(
            at: currentRoot.appendingPathComponent("\(variant)-backup"))
        // An unrelated directory outside any repo-owned root must survive.
        let unrelatedPath = try createDirectory(
            at: tempRoot.appendingPathComponent("\(variant)-notes"))

        let report = ModelCachePathResolver.removeVariantDirectories(
            for: variant,
            roots: roots
        )

        XCTAssertEqual(
            Set(report.deletedPaths.map(normalizedPath)),
            Set([directPath, nestedPath].map(normalizedPath))
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: directPath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedPath.path))
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
