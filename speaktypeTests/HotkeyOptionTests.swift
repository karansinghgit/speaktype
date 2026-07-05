import XCTest
import AppKit
@testable import speaktype

/// Covers the hotkey model, focused on the Option+Space chord added this
/// session (previously zero coverage — the chord's keyCode/modifier/isChord
/// classification is what the AppDelegate event-tap logic branches on).
final class HotkeyOptionTests: XCTestCase {

    func testOptionSpaceChordProperties() {
        let chord = HotkeyOption.optionSpace
        XCTAssertEqual(chord.keyCode, 49, "Option+Space chord must key off the Space keycode (49)")
        XCTAssertEqual(chord.modifierFlag, .option)
        XCTAssertTrue(chord.isChord, "optionSpace is the only modifier+key chord")
        XCTAssertEqual(chord.displayName, "⌥ + Space")
    }

    func testOnlyOptionSpaceIsAChord() {
        for option in HotkeyOption.allCases where option != .optionSpace {
            XCTAssertFalse(
                option.isChord,
                "\(option.rawValue) is a bare modifier, not a chord")
        }
    }

    func testBareModifierOptionsUseModifierKeyCodes() {
        // The non-chord options fire on a modifier's own keyDown/flagsChanged,
        // so their keyCode must be a modifier keycode, never Space (49).
        for option in HotkeyOption.allCases where !option.isChord {
            XCTAssertNotEqual(
                option.keyCode, 49,
                "\(option.rawValue) should not use the Space keycode")
        }
    }

    func testModifierFlagMapping() {
        XCTAssertEqual(HotkeyOption.fn.modifierFlag, .function)
        XCTAssertEqual(HotkeyOption.leftCommand.modifierFlag, .command)
        XCTAssertEqual(HotkeyOption.rightCommand.modifierFlag, .command)
        XCTAssertEqual(HotkeyOption.leftControl.modifierFlag, .control)
        XCTAssertEqual(HotkeyOption.rightControl.modifierFlag, .control)
        XCTAssertEqual(HotkeyOption.leftOption.modifierFlag, .option)
        XCTAssertEqual(HotkeyOption.rightOption.modifierFlag, .option)
        XCTAssertEqual(HotkeyOption.optionSpace.modifierFlag, .option)
    }

    func testDefaultIsFn() {
        XCTAssertEqual(HotkeyOption.default, .fn)
    }

    func testRawValueRoundTripForEveryCase() {
        for option in HotkeyOption.allCases {
            XCTAssertEqual(
                HotkeyOption(rawValue: option.rawValue), option,
                "rawValue round-trip failed for \(option.rawValue) — persistence would break")
        }
    }

    func testAllCasesIncludeChordAndHaveUniqueDisplayNames() {
        XCTAssertTrue(HotkeyOption.allCases.contains(.optionSpace))
        let names = HotkeyOption.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "hotkey display names must be unique in the picker")
    }
}
