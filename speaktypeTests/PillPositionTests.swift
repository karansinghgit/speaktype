import XCTest
import Cocoa
@testable import speaktype

final class PillPositionTests: XCTestCase {
    // 1440x900 with a 25px menu bar and 70px dock, leaving visibleFrame
    // (0, 70, 1440, 805). Matches what AppKit reports for a typical
    // MacBook display with the dock pinned to the bottom.
    private let visibleFrame = NSRect(x: 0, y: 70, width: 1440, height: 805)
    private let panelSize = NSSize(width: 520, height: 84)
    private let edgeInset: CGFloat = 8

    func testTopRight_landsInTopRightCorner() {
        let origin = PillPosition.origin(
            for: .topRight,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.maxX - panelSize.width - edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.maxY - panelSize.height - edgeInset)
    }

    func testTopLeft_landsInTopLeftCorner() {
        let origin = PillPosition.origin(
            for: .topLeft,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.minX + edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.maxY - panelSize.height - edgeInset)
    }

    func testBottomCenter_isHorizontallyCentered() {
        let origin = PillPosition.origin(
            for: .bottomCenter,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.midX - panelSize.width / 2)
        XCTAssertEqual(origin.y, visibleFrame.minY + edgeInset)
    }

    func testBottomRight_usesRightEdge() {
        let origin = PillPosition.origin(
            for: .bottomRight,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.maxX - panelSize.width - edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.minY + edgeInset)
    }

    func testCenter_isScreenCentered() {
        let origin = PillPosition.origin(
            for: .center,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.midX - panelSize.width / 2)
        XCTAssertEqual(origin.y, visibleFrame.midY - panelSize.height / 2)
    }

    func testCenterRight_sitsAtVerticalCenterOnRightEdge() {
        let origin = PillPosition.origin(
            for: .centerRight,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.maxX - panelSize.width - edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.midY - panelSize.height / 2)
    }

    func testTopCenter_isHorizontallyCenteredAtTop() {
        let origin = PillPosition.origin(
            for: .topCenter,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.midX - panelSize.width / 2)
        XCTAssertEqual(origin.y, visibleFrame.maxY - panelSize.height - edgeInset)
    }

    func testCenterLeft_sitsAtVerticalCenterOnLeftEdge() {
        let origin = PillPosition.origin(
            for: .centerLeft,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.minX + edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.midY - panelSize.height / 2)
    }

    func testBottomLeft_landsInBottomLeftCorner() {
        let origin = PillPosition.origin(
            for: .bottomLeft,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            edgeInset: edgeInset
        )
        XCTAssertEqual(origin.x, visibleFrame.minX + edgeInset)
        XCTAssertEqual(origin.y, visibleFrame.minY + edgeInset)
    }

    func testDefaultPosition_isBottomCenter() {
        XCTAssertEqual(PillPosition.defaultPosition, .bottomCenter)
    }

    func testDefaultsKey_isStable() {
        // If this changes, any installed user's saved preference is lost.
        XCTAssertEqual(PillPosition.defaultsKey, "recorderPillPosition")
    }

    func testAllCases_haveUniqueRawValues() {
        let raws = PillPosition.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count)
    }
}
