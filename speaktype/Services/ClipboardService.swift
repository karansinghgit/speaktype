import Cocoa
import ApplicationServices

class ClipboardService {
    static let shared = ClipboardService()
    
    private init() {}
    
    // Copy text to system clipboard
    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Copied to clipboard: \(text.prefix(20))...")
    }
    
    // Paste content (Simulate Cmd+V)
    func paste() {
        // Create a concurrent task to avoid blocking main thread if needed,
        // though CGEvent is fast.
        DispatchQueue.main.async {
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Command key down
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
            cmdDown?.flags = .maskCommand
            
            // 'V' key down
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            
            // 'V' key up
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            
            // Command key up
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
            
            // Post events
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
            
            print("Simulated Cmd+V")
        }
    }
}
