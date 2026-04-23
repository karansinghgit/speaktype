import Security
import XCTest
@testable import speaktype

final class UpdateServiceSecurityTests: XCTestCase {

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
}
