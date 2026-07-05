import Security
import XCTest
@testable import speaktype

final class UpdateServiceSecurityTests: XCTestCase {

    func testRegisterDefaultsEnablesAutoUpdateForFreshDefaults() {
        let suiteName = "UpdateServiceSecurityTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: UpdateService.autoUpdateDefaultsKey)

        UpdateService.registerDefaults(in: defaults)

        XCTAssertFalse(defaults.bool(forKey: UpdateService.autoUpdateDefaultsKey))

        defaults.removeObject(forKey: UpdateService.autoUpdateDefaultsKey)
        UpdateService.registerDefaults(in: defaults)

        XCTAssertTrue(defaults.bool(forKey: UpdateService.autoUpdateDefaultsKey))
    }

    func testReleaseVersionNormalizationOnlyStripsLeadingV() {
        XCTAssertEqual(AppVersion.normalizedReleaseVersion(from: "v1.2.3-dev"), "1.2.3-dev")
        XCTAssertEqual(AppVersion.normalizedReleaseVersion(from: "V1.2.3"), "1.2.3")
        XCTAssertEqual(AppVersion.normalizedReleaseVersion(from: "1.2.3-dev"), "1.2.3-dev")
    }

    func testTrustedUpdateRequirementStringPinsBundleAndTeam() {
        let requirement = UpdateService.trustedUpdateRequirementString(
            bundleIdentifier: "com.example.app",
            teamIdentifier: "TEAM123456"
        )

        XCTAssertEqual(
            requirement,
            #"identifier "com.example.app" and anchor apple generic and certificate leaf[subject.OU] = "TEAM123456""#
        )
    }

    func testValidateSigningInfoAcceptsMatchingIdentity() {
        let signingInfo: [String: Any] = [
            kSecCodeInfoIdentifier as String: UpdateService.trustedUpdateBundleIdentifier,
            kSecCodeInfoTeamIdentifier as String: UpdateService.trustedUpdateTeamIdentifier,
        ]

        XCTAssertNoThrow(
            try UpdateService.validateSigningInfo(
                signingInfo,
                expectedBundleIdentifier: UpdateService.trustedUpdateBundleIdentifier,
                expectedTeamIdentifier: UpdateService.trustedUpdateTeamIdentifier
            )
        )
    }

    func testValidateSigningInfoRejectsUnexpectedBundleIdentifier() {
        let signingInfo: [String: Any] = [
            kSecCodeInfoIdentifier as String: "com.example.other",
            kSecCodeInfoTeamIdentifier as String: UpdateService.trustedUpdateTeamIdentifier,
        ]

        XCTAssertThrowsError(
            try UpdateService.validateSigningInfo(
                signingInfo,
                expectedBundleIdentifier: UpdateService.trustedUpdateBundleIdentifier,
                expectedTeamIdentifier: UpdateService.trustedUpdateTeamIdentifier
            )
        ) { error in
            guard case UpdateError.invalidCandidateApp = error else {
                return XCTFail("Expected invalidCandidateApp, got \(error)")
            }
        }
    }

    func testValidateSigningInfoRejectsUnexpectedTeamIdentifier() {
        let signingInfo: [String: Any] = [
            kSecCodeInfoIdentifier as String: UpdateService.trustedUpdateBundleIdentifier,
            kSecCodeInfoTeamIdentifier as String: "TEAM999999",
        ]

        XCTAssertThrowsError(
            try UpdateService.validateSigningInfo(
                signingInfo,
                expectedBundleIdentifier: UpdateService.trustedUpdateBundleIdentifier,
                expectedTeamIdentifier: UpdateService.trustedUpdateTeamIdentifier
            )
        ) { error in
            XCTAssertEqual(error as? UpdateError, .untrustedDeveloper)
        }
    }

    func testValidateCandidateVersionAcceptsMatchingVersionWithoutBuildBinding() {
        XCTAssertNoThrow(
            try UpdateService.validateCandidateVersion(
                candidateVersion: "1.2.3",
                candidateBuild: "26",
                expectedVersion: "1.2.3",
                expectedBuild: nil
            )
        )
    }

    func testValidateCandidateVersionRejectsOlderSignedCandidate() {
        XCTAssertThrowsError(
            try UpdateService.validateCandidateVersion(
                candidateVersion: "1.2.2",
                candidateBuild: "25",
                expectedVersion: "1.2.3",
                expectedBuild: nil
            )
        ) { error in
            guard case UpdateError.invalidCandidateApp = error else {
                return XCTFail("Expected invalidCandidateApp, got \(error)")
            }
        }
    }

    func testValidateCandidateVersionRejectsMismatchedBuildWhenExpected() {
        XCTAssertThrowsError(
            try UpdateService.validateCandidateVersion(
                candidateVersion: "1.2.3",
                candidateBuild: "25",
                expectedVersion: "1.2.3",
                expectedBuild: "26"
            )
        ) { error in
            guard case UpdateError.invalidCandidateApp = error else {
                return XCTFail("Expected invalidCandidateApp, got \(error)")
            }
        }
    }

    func testNormalizedExpectedBuildIgnoresPlaceholderBuild() {
        XCTAssertNil(UpdateService.normalizedExpectedBuild("0"))
        XCTAssertNil(UpdateService.normalizedExpectedBuild("  "))
        XCTAssertEqual(UpdateService.normalizedExpectedBuild("26"), "26")
    }

    func testRelaunchShellArgumentsKeepBundlePathOutOfShellSource() {
        let bundlePath = "/Applications/SpeakType $(touch /tmp/pwned).app"
        let arguments = UpdateService.relaunchShellArguments(pid: 1234, bundlePath: bundlePath)

        XCTAssertEqual(arguments.count, 5)
        XCTAssertEqual(arguments[0], "-c")
        XCTAssertFalse(arguments[1].contains(bundlePath))
        XCTAssertFalse(arguments[1].contains("$(touch"))
        XCTAssertTrue(arguments[1].contains("\"$2\""))
        XCTAssertEqual(arguments[3], "1234")
        XCTAssertEqual(arguments[4], bundlePath)
    }
}
