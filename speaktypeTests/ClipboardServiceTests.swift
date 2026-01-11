import XCTest
@testable import speaktype

final class ClipboardServiceTests: XCTestCase {
    
    func testCopy() {
        let text = "Copied Text Check"
        ClipboardService.shared.copy(text: text)
        
        let pasteboard = NSPasteboard.general
        let copied = pasteboard.string(forType: .string)
        
        XCTAssertEqual(copied, text, "Clipboard content should match copied text")
    }
    
    // Testing paste() is difficult in unit tests as it requires active application focus and AX permissions.
    // We primarily verify the write operation here.
}
