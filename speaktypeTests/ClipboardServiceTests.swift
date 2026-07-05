import XCTest
import Cocoa
@testable import speaktype

final class ClipboardServiceTests: XCTestCase {
    
    func testCopy() {
        let text = "Copied Text Check"
        ClipboardService.shared.copy(text: text)
        
        let pasteboard = NSPasteboard.general
        let copied = pasteboard.string(forType: .string)
        
        XCTAssertEqual(copied, text, "Clipboard content should match copied text")
    }

    func testTemporaryPasteCanRestorePreviousClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("https://example.com/original", forType: .string)

        let snapshot = ClipboardService.shared.copyForTemporaryPaste(text: "Dictated text")
        XCTAssertEqual(pasteboard.string(forType: .string), "Dictated text")

        ClipboardService.shared.restore(snapshot, ifCurrentStringMatches: "Dictated text")
        XCTAssertEqual(pasteboard.string(forType: .string), "https://example.com/original")
    }

    func testRestoreDoesNotOverwriteClipboardChangedAfterPaste() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("Original clipboard", forType: .string)

        let snapshot = ClipboardService.shared.copyForTemporaryPaste(text: "Dictated text")
        pasteboard.clearContents()
        pasteboard.setString("User copied something else", forType: .string)

        ClipboardService.shared.restore(snapshot, ifCurrentStringMatches: "Dictated text")
        XCTAssertEqual(pasteboard.string(forType: .string), "User copied something else")
    }

    func testClipboardVerificationDoesNotLogCopiedText() throws {
        let source = try repositorySourceFile("speaktype/Services/ClipboardService.swift")

        XCTAssertFalse(source.contains("check.prefix"))
        XCTAssertFalse(source.contains("Clipboard Write Verified: '"))
    }
    
    // Testing paste() is difficult in unit tests as it requires active application focus and AX permissions.
    // We primarily verify the write operation here.

    private func repositorySourceFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
