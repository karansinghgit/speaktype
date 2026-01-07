import Cocoa
import Carbon
import Combine

class HotkeyService: ObservableObject {
    static let shared = HotkeyService()
    
    // Default hotkey: Option + Shift + Space
    // We can make this configurable later
    private var hotKeyRef: EventHotKeyRef?
    
    @Published var isPressed = false
    
    private init() {
        registerHotkey()
    }
    
    func registerHotkey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Install handler for Key Pressed
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Handle Hotkey Pressed
            print("Hotkey Pressed")
            NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
            return noErr
        }, 1, &eventType, nil, nil)
        
        // Install handler for Key Released
        var releaseEventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyReleased)
        )
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Handle Hotkey Released
            print("Hotkey Released")
             NotificationCenter.default.post(name: .hotkeyReleased, object: nil)
            return noErr
        }, 1, &releaseEventType, nil, nil)
        
        // Register the actual hotkey (Option + Shift + Space)
        // 49 is Space
        // modifiers: optionKey + shiftKey
        let hotKeyID = EventHotKeyID(signature: OSType(0x5357), id: 1) // Signature 'SW', ID 1
        var gMyHotKeyRef: EventHotKeyRef? = nil
        
        // modifiers: cmdKey = 256, shiftKey = 512, optionKey = 2048, controlKey = 4096
        // preferring Control + Shift + Space to avoid conflicts? 
        // User requested "press-and-hold", picking Option+Space or similar is common.
        // Let's go with Option + Space (common for launchers) or Shift+Option+Space.
        // Let's use Option + Space (49 + 2048) for now.
        
        let modifiers = optionKey
        
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
        hotKeyRef = gMyHotKeyRef
    }
    
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("hotkeyPressed")
    static let hotkeyReleased = Notification.Name("hotkeyReleased")
}
