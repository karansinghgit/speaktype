# SpeakType Implementation Plan

## Project Overview
A macOS system-wide voice-to-text utility that enables fast, offline voice dictation across all applications. Inspired by VoiceInk, with a goal to ship an MVP within 3-4 days.

## Timeline: 3-4 Days MVP

---

## Phase 1: Foundation & Setup (Day 1 - Morning)
**Goal**: Set up core project structure and dependencies

### 1.1 Project Configuration & Dependencies
- [ ] Update `Info.plist` with required permissions
  - Microphone usage description
  - Accessibility API usage description
- [ ] Add entitlements
  - `com.apple.security.device.microphone`
  - `com.apple.security.automation.apple-events`
  - App Sandbox with necessary permissions
- [ ] Research and integrate Whisper model
  - Evaluate `whisper.cpp` Swift bindings
  - Alternative: `WhisperKit` framework
  - Download base/small model files
- [ ] Update Xcode project settings
  - Set minimum macOS version to 13.0+
  - Configure build settings for menu bar app
  - Add LSUIElement = YES for menu bar only app

### 1.2 Core Models
**Files to create in `Models/`:**
- [ ] `TranscriptionState.swift` - Enum for app states (idle, listening, transcribing, ready)
- [ ] `TranscriptionResult.swift` - Model for transcription data
- [ ] `AppSettings.swift` - User preferences model
- [ ] `RecordingSession.swift` - Audio recording session data
- [ ] `HotkeyConfiguration.swift` - Keyboard shortcut configuration

---

## Phase 2: Core Services (Day 1 - Afternoon)
**Goal**: Implement essential services for audio, transcription, and system integration

### 2.1 Audio Service
**Create `Services/Audio/`:**
- [ ] `AudioRecordingService.swift`
  - Initialize AVAudioEngine
  - Configure audio session
  - Start/stop recording
  - Buffer audio data
  - Handle microphone permissions
- [ ] `AudioBufferManager.swift`
  - Manage audio buffer
  - Convert audio format for Whisper
  - Handle memory efficiently
- [ ] `AudioDeviceManager.swift`
  - Enumerate available audio input devices
  - Select/switch between devices
  - Monitor device changes (connect/disconnect)
  - Get device metadata (name, sample rate, channels)
- [ ] `MicrophonePermissionManager.swift`
  - Request microphone access
  - Handle permission states
  - Provide user-friendly error messages

### 2.2 Transcription Service
**Create `Services/Transcription/`:**
- [ ] `WhisperService.swift`
  - Initialize Whisper model
  - Load model on app launch
  - Transcribe audio buffer
  - Handle model lifecycle
  - Support base/small model selection
- [ ] `TranscriptionQueue.swift`
  - Queue transcription requests
  - Handle concurrent requests
  - Cancel pending requests
- [ ] `TranscriptionCache.swift` (optional)
  - Cache recent transcriptions
  - Improve performance

### 2.3 System Integration Services
**Create `Services/System/`:**
- [ ] `HotkeyService.swift`
  - Register global keyboard shortcut
  - Handle press and release events
  - Support customizable hotkeys
  - Use Carbon or modern Swift alternatives
- [ ] `ClipboardService.swift`
  - Copy text to clipboard
  - Read current clipboard (if needed)
  - Handle clipboard history
- [ ] `AccessibilityService.swift`
  - Request accessibility permissions
  - Implement auto-paste functionality
  - Get active application
  - Paste text programmatically
- [ ] `PermissionCoordinator.swift`
  - Centralize permission management
  - Check all required permissions
  - Guide user through permission setup

---

## Phase 3: UI Components (Day 2 - Morning)
**Goal**: Build all UI components following macOS design guidelines

### 3.1 Menu Bar Integration
**Create `Views/MenuBar/`:**
- [ ] `MenuBarView.swift`
  - Menu bar icon with SF Symbol
  - Status indicator overlay
  - Popover presentation
- [ ] `MenuBarPopoverView.swift`
  - App status display
  - Quick action buttons
  - Settings navigation
  - Quit button

### 3.2 Floating Overlays
**Create `Views/Overlays/`:**
- [ ] `ListeningOverlayView.swift`
  - Centered floating panel
  - "Listening..." title
  - Recording indicator (animated)
  - Waveform visualization (optional)
  - Instructions text
  - Blur/vibrancy background
- [ ] `TranscribingOverlayView.swift`
  - "Transcribing..." message
  - Loading spinner
  - Cancel button (optional)

### 3.3 Result Display
**Create `Views/Results/`:**
- [ ] `TranscriptionResultView.swift`
  - Scrollable text display
  - Editable text field
  - Action buttons (Copy, Paste, Save, Dismiss)
  - Keyboard shortcuts
  - Auto-dismiss timer option

### 3.4 Settings Screen
**Create `Views/Settings/`:**
- [ ] `SettingsView.swift`
  - Tab-based navigation (SwiftUI native)
  - Organized sections
- [ ] `GeneralSettingsView.swift`
  - Hotkey customization
  - Launch at login toggle
  - Status in menu bar preferences
- [ ] `AudioInputSettingsView.swift`
  - Audio device selection
  - Input mode (System Default, Custom Device, Prioritized)
  - Device list with active indicator
  - Refresh devices button
- [ ] `TranscriptionSettingsView.swift`
  - Model selection (Base/Small)
  - Model details (size, speed, accuracy indicators)
  - Download/manage models
  - Language (English - fixed for MVP)
  - Show confidence scores (optional)
- [ ] `ClipboardSettingsView.swift`
  - Auto-paste toggle
  - Auto-dismiss result panel
  - Clipboard history (optional)
- [ ] `AboutSettingsView.swift`
  - App version
  - Open-source notice
  - GitHub link
  - Privacy policy
  - Model information

### 3.5 Permission Screens
**Create `Views/Permissions/`:**
- [ ] `PermissionOnboardingView.swift`
  - First-launch wizard
  - Explain required permissions
  - Guide to system preferences
- [ ] `PermissionRequestView.swift`
  - Individual permission cards
  - Open System Preferences buttons
  - Status indicators

### 3.6 Reusable Components
**Create `Views/Components/`:**
- [ ] `RecordingIndicator.swift`
  - Animated recording dot
  - Customizable colors
- [ ] `WaveformView.swift` (optional)
  - Real-time waveform visualization
  - Level meter
- [ ] `StatusBadge.swift`
  - Color-coded status indicators
- [ ] `ActionButton.swift`
  - Consistent button styling
  - Hover effects
- [ ] `FloatingPanel.swift`
  - Reusable floating window wrapper
  - Blur/vibrancy materials

---

## Phase 4: ViewModels & State Management (Day 2 - Afternoon)
**Goal**: Connect UI to services with proper state management

### 4.1 Core ViewModels
**Create `ViewModels/`:**
- [ ] `AppViewModel.swift`
  - Central app state coordinator
  - Manage app lifecycle
  - Coordinate between services
  - Handle global hotkey events
  - Publish transcription states
- [ ] `RecordingViewModel.swift`
  - Control recording session
  - Monitor audio levels
  - Handle start/stop events
  - Publish recording duration
- [ ] `TranscriptionViewModel.swift`
  - Manage transcription process
  - Handle results
  - Error handling
  - Retry logic
- [ ] `SettingsViewModel.swift`
  - Manage user preferences
  - Persist settings
  - Handle hotkey changes
  - Model selection
- [ ] `PermissionViewModel.swift`
  - Check permission status
  - Request permissions
  - Guide user to settings
  - Track permission states

### 4.2 State Management
**Create `State/`:**
- [ ] `AppState.swift`
  - Global app state (Environment Object)
  - Current transcription state
  - Active recording session
  - Settings
- [ ] `NotificationCenter+App.swift`
  - Custom notifications for app events
  - Hotkey pressed/released
  - Transcription complete
  - Error notifications

---

## Phase 5: Storage & Persistence (Day 2 - Evening)
**Goal**: Implement data persistence

### 5.1 Settings Storage
**Create `Services/Storage/`:**
- [ ] `SettingsStorageService.swift`
  - UserDefaults wrapper
  - Save/load app settings
  - Default values
  - Migration support
- [ ] `HotkeyStorageService.swift`
  - Persist hotkey configuration
  - Validate hotkey combinations

### 5.2 Optional History
**Create if time permits:**
- [ ] `TranscriptionHistoryService.swift`
  - Store recent transcriptions
  - Limit storage size
  - Clear history option
- [ ] `TranscriptionHistory.swift` model

---

## Phase 6: Integration & App Flow (Day 3 - Morning)
**Goal**: Wire everything together into complete user flows

### 6.1 App Entry Point
**Update `App/`:**
- [ ] `speaktypeApp.swift`
  - Initialize as menu bar app
  - Set up environment objects
  - Load Whisper model on launch
  - Register global hotkey
  - Show permissions if needed
- [ ] `AppDelegate.swift`
  - Handle app lifecycle events
  - Terminate behavior
  - Dock icon management

### 6.2 Main Coordinator
**Create `Coordinators/`:**
- [ ] `AppCoordinator.swift`
  - Coordinate user flows
  - Manage window presentation
  - Handle hotkey events
  - Show/hide overlays
  - Navigate to settings

### 6.3 Window Management
**Create `Utilities/Windows/`:**
- [ ] `WindowManager.swift`
  - Manage floating windows
  - Position windows (center, etc.)
  - Window levels (floating on top)
  - Focus management
- [ ] `PanelWindowController.swift`
  - Custom NSPanel for overlays
  - Transparency support
  - Click-through behavior

---

## Phase 7: Complete User Flows (Day 3 - Afternoon)
**Goal**: Implement end-to-end functionality

### 7.1 Recording Flow
**Implementation sequence:**
1. [ ] User presses hotkey
2. [ ] HotkeyService detects press
3. [ ] AppViewModel updates state to `.listening`
4. [ ] ListeningOverlayView appears
5. [ ] AudioRecordingService starts recording
6. [ ] Waveform/indicator shows activity
7. [ ] User releases hotkey
8. [ ] AudioRecordingService stops recording
9. [ ] AppViewModel updates state to `.transcribing`
10. [ ] TranscribingOverlayView appears
11. [ ] WhisperService transcribes audio
12. [ ] AppViewModel updates state to `.ready`
13. [ ] TranscriptionResultView appears with text
14. [ ] ClipboardService copies text
15. [ ] (Optional) AccessibilityService pastes text
16. [ ] Auto-dismiss or wait for user action

### 7.2 Settings Flow
**Implementation:**
- [ ] Click settings in menu bar popover
- [ ] Open settings window
- [ ] Update preferences
- [ ] Save changes
- [ ] Apply changes immediately

### 7.3 Error Flows
**Handle edge cases:**
- [ ] Microphone permission denied
- [ ] Accessibility permission denied
- [ ] Model loading failure
- [ ] Transcription error
- [ ] No audio detected
- [ ] Empty transcription result

---

## Phase 8: Polish & Refinement (Day 3 - Evening)
**Goal**: Improve UX and fix issues

### 8.1 Visual Polish
- [ ] Implement blur/vibrancy effects
- [ ] Add smooth animations
  - Overlay fade in/out
  - Recording indicator pulse
  - Button hover effects
- [ ] Support light/dark mode
- [ ] Adjust spacing and sizing
- [ ] Icon refinement

### 8.2 UX Improvements
- [ ] Keyboard shortcuts for result panel
- [ ] Escape to dismiss overlays
- [ ] Sound feedback (optional)
- [ ] Haptic feedback if supported
- [ ] Loading states
- [ ] Empty states
- [ ] Error messages user-friendly

### 8.3 Performance Optimization
- [ ] Lazy load Whisper model
- [ ] Optimize audio buffer size
- [ ] Reduce memory footprint
- [ ] Test with long recordings
- [ ] Profile with Instruments

---

## Phase 9: Testing & Bug Fixes (Day 4 - Morning)
**Goal**: Ensure stability and reliability

### 9.1 Unit Tests
**Create in `speaktypeTests/`:**
- [ ] `AudioRecordingServiceTests.swift`
- [ ] `ClipboardServiceTests.swift`
- [ ] `SettingsStorageServiceTests.swift`
- [ ] `AppViewModelTests.swift`
- [ ] `TranscriptionViewModelTests.swift`

### 9.2 Integration Tests
- [ ] Test full recording → transcription → paste flow
- [ ] Test permission flows
- [ ] Test settings persistence
- [ ] Test hotkey registration

### 9.3 Manual Testing
**Test scenarios:**
- [ ] First launch experience
- [ ] Permission requests
- [ ] Record short utterance (3-5 seconds)
- [ ] Record long utterance (30+ seconds)
- [ ] Test in various apps (Notes, Safari, Messages, etc.)
- [ ] Change hotkey
- [ ] Change model
- [ ] Test with no microphone
- [ ] Test with denied permissions
- [ ] Light/dark mode switching
- [ ] System sleep/wake

### 9.4 Bug Fixes
- [ ] Fix crashes
- [ ] Fix memory leaks
- [ ] Fix UI glitches
- [ ] Fix permission issues
- [ ] Fix transcription errors

---

## Phase 10: Documentation & Release Prep (Day 4 - Afternoon)
**Goal**: Prepare for release

### 10.1 Documentation
- [ ] Update `README.md`
  - Feature list
  - Installation instructions
  - Usage guide
  - Screenshots/GIFs
  - Permissions explanation
- [ ] Create `docs/USER_GUIDE.md`
  - Getting started
  - Keyboard shortcuts
  - Settings explanation
  - Troubleshooting
- [ ] Create `docs/PRIVACY.md`
  - Local-only processing
  - No data collection
  - Permissions explanation
- [ ] Update `LICENSE` (MIT or Apache 2.0)
- [ ] Create `CHANGELOG.md`

### 10.2 Code Quality
- [ ] Run SwiftLint and fix warnings
- [ ] Add code documentation
- [ ] Clean up commented code
- [ ] Remove debug logs
- [ ] Code review

### 10.3 Build & Package
- [ ] Create Release build configuration
- [ ] Archive for distribution
- [ ] Code signing setup
- [ ] Notarization (if distributing outside App Store)
- [ ] Create DMG installer (optional)

### 10.4 Repository Setup
- [ ] Create GitHub repository
- [ ] Push code
- [ ] Add README with badges
- [ ] Create release notes
- [ ] Tag v1.0.0

---

## Technical Architecture

### Key Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + AppKit (for menu bar)
- **Speech Recognition**: whisper.cpp or WhisperKit
- **Audio**: AVFoundation
- **Hotkeys**: Carbon API or modern alternative
- **Persistence**: UserDefaults

### Third-Party Dependencies
1. **Whisper Integration** (Choose one):
   - `WhisperKit` - Swift package by Argmax
   - `whisper.cpp` - C++ implementation with Swift bindings
   
2. **Global Hotkeys** (Choose one):
   - `KeyboardShortcuts` - Swift package by Sindre Sorhus
   - Custom Carbon API wrapper
   
3. **Optional**:
   - `LaunchAtLogin` - Swift package for launch at login

### Data Flow
```
User → Hotkey Press
  ↓
Audio Recording Service
  ↓
Audio Buffer
  ↓
Whisper Service
  ↓
Transcription Result
  ↓
Clipboard Service
  ↓
(Optional) Accessibility Service → Paste
```

### State Machine
```
Idle → Listening → Transcribing → Ready → Idle
         ↓            ↓            ↓
      (Error) →   (Error) →   (Error) → Idle
```

---

## File Structure Overview

```
speaktype/
├── App/
│   ├── speaktypeApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── TranscriptionState.swift
│   ├── TranscriptionResult.swift
│   ├── AppSettings.swift
│   ├── RecordingSession.swift
│   ├── HotkeyConfiguration.swift
│   └── AudioDevice.swift
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift
│   │   └── MenuBarPopoverView.swift
│   ├── Overlays/
│   │   ├── ListeningOverlayView.swift
│   │   └── TranscribingOverlayView.swift
│   ├── Results/
│   │   └── TranscriptionResultView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsView.swift
│   │   ├── TranscriptionSettingsView.swift
│   │   ├── ClipboardSettingsView.swift
│   │   └── AboutSettingsView.swift
│   ├── Permissions/
│   │   ├── PermissionOnboardingView.swift
│   │   └── PermissionRequestView.swift
│   └── Components/
│       ├── RecordingIndicator.swift
│       ├── WaveformView.swift
│       ├── StatusBadge.swift
│       ├── ActionButton.swift
│       └── FloatingPanel.swift
├── ViewModels/
│   ├── AppViewModel.swift
│   ├── RecordingViewModel.swift
│   ├── TranscriptionViewModel.swift
│   ├── SettingsViewModel.swift
│   └── PermissionViewModel.swift
├── Services/
│   ├── Audio/
│   │   ├── AudioRecordingService.swift
│   │   ├── AudioBufferManager.swift
│   │   ├── AudioDeviceManager.swift
│   │   └── MicrophonePermissionManager.swift
│   ├── Transcription/
│   │   ├── WhisperService.swift
│   │   ├── TranscriptionQueue.swift
│   │   └── TranscriptionCache.swift
│   ├── System/
│   │   ├── HotkeyService.swift
│   │   ├── ClipboardService.swift
│   │   ├── AccessibilityService.swift
│   │   └── PermissionCoordinator.swift
│   └── Storage/
│       ├── SettingsStorageService.swift
│       ├── HotkeyStorageService.swift
│       └── TranscriptionHistoryService.swift
├── Coordinators/
│   └── AppCoordinator.swift
├── State/
│   ├── AppState.swift
│   └── NotificationCenter+App.swift
├── Utilities/
│   ├── Windows/
│   │   ├── WindowManager.swift
│   │   └── PanelWindowController.swift
│   ├── Extensions/
│   │   ├── View+Extensions.swift
│   │   ├── Color+Extensions.swift
│   │   └── NSApplication+Extensions.swift
│   └── Constants.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Info.plist
    └── speaktype.entitlements
```

---

## Risk Mitigation

### High-Risk Items
1. **Whisper Integration** (HIGH PRIORITY - Day 1)
   - Risk: Complex integration, large model files
   - Mitigation: Research on Day 1 morning, have fallback option
   - Fallback: Use system Speech framework temporarily

2. **Global Hotkeys** (HIGH PRIORITY - Day 1)
   - Risk: macOS permissions, deprecated APIs
   - Mitigation: Use proven Swift package (KeyboardShortcuts)
   - Fallback: Manual activation from menu bar

3. **Auto-paste Functionality** (MEDIUM PRIORITY)
   - Risk: Accessibility permissions complex
   - Mitigation: Make it optional, default to clipboard only
   - Fallback: Copy to clipboard only

4. **Performance** (MEDIUM PRIORITY)
   - Risk: Model loading slow, transcription lag
   - Mitigation: Load model on app launch, optimize audio format
   - Test: Profile early and often

### Contingency Plans
- If Whisper integration takes too long → Use macOS Speech framework
- If auto-paste is problematic → Focus on clipboard functionality
- If custom UI is complex → Simplify to basic SwiftUI components
- If 3-4 days is tight → Cut optional features (waveform, history)

---

## Success Metrics (MVP)

### Functional Requirements
- ✅ Press hotkey → speak → release → text in clipboard
- ✅ Works offline
- ✅ Works in any text field
- ✅ Transcription accuracy >80% for clear speech
- ✅ Latency <5 seconds for short clips (<10 sec speech)

### Quality Requirements
- ✅ No crashes during basic usage
- ✅ Proper error messages
- ✅ Permissions clearly explained
- ✅ Works on macOS 13.0+

### Polish Requirements (Nice to have)
- ✅ Smooth animations
- ✅ Light/dark mode support
- ✅ Keyboard shortcuts
- ✅ Clean, minimal UI

---

## Post-MVP Roadmap

### Version 1.1 (Week 2)
- Real-time streaming transcription
- Multiple language support
- Improved model selection
- Transcription history
- Custom vocabulary

### Version 1.2 (Week 3-4)
- Text formatting commands
- Punctuation auto-formatting
- Custom hotkeys per app
- Profiles/presets
- Cloud sync (optional)

### Version 2.0 (Month 2)
- iOS standalone app
- macOS App Store release
- Pro features
- Advanced settings
- Analytics dashboard

---

## Daily Checkpoints

### Day 1 End
- [ ] Project configured with dependencies
- [ ] Core models defined
- [ ] Audio recording working
- [ ] Whisper integration functional
- [ ] Can record and transcribe (even if UI is basic)

### Day 2 End
- [ ] All UI components built
- [ ] ViewModels connected
- [ ] Settings working
- [ ] Can use app end-to-end (rough but functional)

### Day 3 End
- [ ] Complete user flows working
- [ ] Permissions handled
- [ ] UI polished
- [ ] Major bugs fixed

### Day 4 End
- [ ] Tests written and passing
- [ ] Documentation complete
- [ ] Release build created
- [ ] GitHub repository ready

---

## Resources

### Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [AVFoundation Audio](https://developer.apple.com/documentation/avfoundation/audio/)
- [Accessibility Programming Guide](https://developer.apple.com/accessibility/)
- [Whisper Documentation](https://github.com/openai/whisper)

### Swift Packages
- [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin-Modern)

### Inspiration
- [VoiceInk](https://voices.ink/)
- [Whisper UI Examples](https://github.com/topics/whisper-ui)

---

## Notes

- Prioritize functionality over polish for MVP
- Test on real devices early and often
- Keep UI simple and focused
- Err on the side of fewer features done well
- Document decisions and assumptions
- Commit code frequently with clear messages

---

## Getting Started

To begin implementation:
1. Read this plan thoroughly
2. Set up development environment
3. Start with Phase 1, Task 1.1
4. Check off items as completed
5. Update this document with learnings
6. Adjust timeline if needed

Good luck! 🚀

