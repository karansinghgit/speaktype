# SpeakType Phase Testing Guide

Quick tests to verify each phase works before moving to the next one.

---

## ✅ Phase 1: Foundation (DONE)

### Test 1: Project Builds
```bash
cd /Users/karansingh/projects/iosapps/speaktype
xcodebuild -scheme speaktype -destination 'platform=macOS' clean build
```
**Pass**: Build succeeds  
**Fail**: Build errors

### Test 2: Models Import
Add to `ContentView.swift`:
```swift
let state: TranscriptionState = .idle
let settings = AppSettings.default
```
**Pass**: No compile errors  
**Fail**: "Cannot find type" errors

### Manual Setup Needed:
1. Open `speaktype.xcodeproj` in Xcode
2. Add WhisperKit package: `https://github.com/argmaxinc/WhisperKit`
3. Add all model files to Xcode project (right-click Models folder → Add Files)
4. Set Info.plist path in Build Settings
5. Set entitlements path in Build Settings

---

## 🎤 Phase 2: Core Services

### Test 1: Microphone Permission
Run app → Should request microphone permission

**Pass**: Permission dialog appears  
**Fail**: No dialog or crash

### Test 2: Audio Recording
Add test button to ContentView:
```swift
Button("Test Record") {
    let recorder = AudioRecordingService()
    recorder.startRecording()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        recorder.stopRecording()
        print("✅ Recording works")
    }
}
```
**Pass**: Prints "✅ Recording works"  
**Fail**: Crash or error

### Test 3: Whisper Transcription
Add test button:
```swift
Button("Test Whisper") {
    Task {
        let service = WhisperService()
        try? await service.initialize()
        print("✅ Whisper loaded")
    }
}
```
**Pass**: Prints "✅ Whisper loaded" after 3-5 seconds  
**Fail**: Crash or never loads

### Test 4: Clipboard Copy
```swift
Button("Test Clipboard") {
    ClipboardService.shared.copy(text: "Hello World")
    let result = ClipboardService.shared.paste()
    print("Clipboard: \(result)")
}
```
**Pass**: Prints "Clipboard: Hello World"  
**Fail**: Empty or wrong text

---

## 🖥️ Phase 3: UI Components

### Test 1: Menu Bar Icon
Run app → Check menu bar (top right)

**Pass**: App icon appears in menu bar  
**Fail**: No icon or dock icon instead

### Test 2: Menu Bar Popover
Click menu bar icon

**Pass**: Popover appears with status  
**Fail**: Nothing happens or crash

### Test 3: Listening Overlay
```swift
Button("Show Listening") {
    // Should show floating "Listening..." panel
    WindowManager.shared.showListeningOverlay()
}
```
**Pass**: Centered floating panel appears  
**Fail**: No panel or crashes

### Test 4: Settings Window
```swift
Button("Open Settings") {
    WindowManager.shared.showSettings()
}
```
**Pass**: Settings window opens with tabs  
**Fail**: No window or crash

---

## 🔗 Phase 4: ViewModels

### Test 1: AppViewModel State
```swift
let viewModel = AppViewModel()
viewModel.startListening()
print("State: \(viewModel.state)")
```
**Pass**: State changes from .idle to .listening  
**Fail**: State doesn't change

### Test 2: Recording → Transcribing Flow
```swift
let viewModel = AppViewModel()
viewModel.startListening()
// Wait 2 seconds
viewModel.stopListening()
// State should go: idle → listening → transcribing → ready
```
**Pass**: State transitions correctly  
**Fail**: Gets stuck or crashes

---

## 💾 Phase 5: Storage

### Test 1: Settings Persistence
```swift
var settings = AppSettings.default
settings.autoPaste = true
SettingsStorageService.shared.save(settings)

let loaded = SettingsStorageService.shared.load()
print("Auto-paste: \(loaded.autoPaste)")
```
**Pass**: Prints "Auto-paste: true"  
**Fail**: Prints false or crashes

### Test 2: Hotkey Storage
```swift
let hotkey = HotkeyConfiguration.default
HotkeyStorageService.shared.save(hotkey)
let loaded = HotkeyStorageService.shared.load()
print("Hotkey: \(loaded.description)")
```
**Pass**: Prints hotkey description  
**Fail**: Nil or crash

---

## 🎯 Phase 6: Integration

### Test 1: Complete App Launch
Run app from Xcode (⌘R)

**Pass**: 
- App icon in menu bar
- Click icon → popover appears
- No crash for 1 minute

**Fail**: Crash or no menu bar icon

### Test 2: Hotkey Registration
Run app → Open Settings → Try changing hotkey

**Pass**: Can press new key combo and it registers  
**Fail**: Can't capture hotkey or crash

---

## 🎬 Phase 7: End-to-End Flow

### THE BIG TEST: Full Recording Flow

1. Run app
2. Press hotkey (default: ⌃⇧Space)
3. Speak: "Hello world this is a test"
4. Release hotkey
5. Wait for transcription
6. Check clipboard

**Pass**: 
- Listening overlay appeared
- Transcribing overlay appeared
- Result panel shows "hello world this is a test"
- Text is in clipboard

**Fail**: Any step breaks or wrong output

### Test 2: Auto-Paste
1. Open Notes app
2. Click in text area
3. Press hotkey
4. Speak: "This should paste automatically"
5. Release hotkey

**Pass**: Text appears in Notes  
**Fail**: Nothing happens or clipboard only

---

## ✨ Phase 8: Polish

### Test 1: Dark Mode
1. Run app
2. System Preferences → Appearance → Dark
3. Check all UI

**Pass**: UI looks good in dark mode  
**Fail**: White text on white, wrong colors

### Test 2: Animations
Watch overlay appear/disappear

**Pass**: Smooth fade in/out  
**Fail**: Instant pop or glitchy

---

## 🧪 Phase 9: Testing

### Test 1: Short Recording
Speak for 2 seconds → Should transcribe in <3 seconds

**Pass**: Fast and accurate  
**Fail**: Slow or wrong text

### Test 2: Long Recording
Speak for 30 seconds → Should transcribe in <10 seconds

**Pass**: Completes without crash  
**Fail**: Crash or timeout

### Test 3: No Speech
Press hotkey, don't speak, release

**Pass**: Shows "No audio detected" or empty result  
**Fail**: Crash

### Test 4: Multiple Apps
Test pasting in: Notes, TextEdit, Safari, Messages

**Pass**: Works in all apps  
**Fail**: Works in some but not others

---

## 📦 Phase 10: Release

### Test 1: Archive Build
```bash
xcodebuild archive -scheme speaktype -archivePath ./build/SpeakType.xcarchive
```
**Pass**: Archive succeeds  
**Fail**: Build errors

### Test 2: Fresh Install Test
1. Delete app from Applications
2. Clear cache: `rm -rf ~/Library/Caches/com.yourcompany.speaktype`
3. Install and run
4. Complete onboarding

**Pass**: Works on fresh install  
**Fail**: Crashes on first run

---

## 🚨 Common Issues & Fixes

### "Microphone permission denied"
Fix: System Preferences → Privacy → Microphone → Check speaktype

### "Accessibility permission denied"
Fix: System Preferences → Privacy → Accessibility → Check speaktype

### "Whisper model not found"
Fix: Check `~/Library/Caches/whisperkit/models/` or re-download

### "Hotkey doesn't work"
Fix: Check no conflicts in System Preferences → Keyboard → Shortcuts

### "Build fails with SwiftUI errors"
Fix: Clean build folder (⌘⇧K) and rebuild

---

## ⏱️ Expected Times

| Phase | Implementation | Testing |
|-------|---------------|---------|
| 1 | 2 hours | 10 min |
| 2 | 3 hours | 15 min |
| 3 | 4 hours | 20 min |
| 4 | 2 hours | 15 min |
| 5 | 1 hour | 10 min |
| 6 | 2 hours | 15 min |
| 7 | 3 hours | 30 min |
| 8 | 2 hours | 15 min |
| 9 | 2 hours | 1 hour |
| 10 | 2 hours | 30 min |
| **Total** | **23 hours** | **3 hours** |

---

## 📋 Intern Checklist

```
[ ] Phase 1 - All tests pass
[ ] Phase 2 - Can record audio + Whisper loads
[ ] Phase 3 - All UI appears correctly
[ ] Phase 4 - State changes work
[ ] Phase 5 - Settings save/load
[ ] Phase 6 - App launches without crash
[ ] Phase 7 - Full flow works (MOST IMPORTANT)
[ ] Phase 8 - Looks good in light/dark
[ ] Phase 9 - All edge cases handled
[ ] Phase 10 - Can build for release
```

---

## 🎯 Definition of Done (Each Phase)

✅ All tests pass  
✅ No compiler warnings  
✅ No crashes in normal use  
✅ Code committed to git  
✅ Brief note of what works/doesn't work

---

## 🆘 When Stuck

1. Check Issue Navigator (⌘5) for errors
2. Clean build (⌘⇧K)
3. Check IMPLEMENTATION_PLAN.md for code examples
4. Google the error message
5. Check [architecture docs](docs/ARCHITECTURE.md)

**Phase 7 is the critical milestone** - if the full recording flow works, you're 80% done!

