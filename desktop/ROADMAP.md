# SpeakType 2

SpeakType 2 is built alongside the current macOS app in `speaktype/`. The old
app keeps shipping until everything below is checked, then it is retired.

Each milestone is tagged `v2.0.0-alpha.N` so any build can be rolled back to.

## Parity with SpeakType 1 (macOS)

### Dictation
- [x] Hold-to-talk and toggle modes
- [x] Fn and single-modifier hotkeys (Right ⌘, Left ⌥…)
- [x] Custom shortcut hotkeys
- [x] Escape stops without pasting, keeps the transcript in History
- [x] Another key while holding the hotkey cancels
- [x] Fn doesn't open the emoji picker
- [x] Paste into the focused app, restore the clipboard afterwards
- [x] Load the model while the user is still speaking
- [ ] Switching microphone mid-recording restarts the recording
- [ ] Accessibility warning the first time dictation can't paste

### Recorder pill
- [x] Recording, transcribing, loading and message states
- [x] Live waveform and elapsed time
- [x] Nine screen positions, always-show option
- [x] Hover controls: microphone, mode, language
- [x] Click the dot to stop
- [ ] Right-click menu to switch model
- [ ] Frosted idle look in light mode

### Transcription
- [x] Whisper models: download, cancel, delete, select
- [x] Recommended model for this machine
- [x] Language choice with recent languages
- [x] Filler-word removal, smart trailing punctuation, dictionary rules
- [x] Parakeet v2 (English) and v3 (25 languages), on CPU, about 25–30x real time on an M3 Pro
- [x] Neural Engine acceleration for Whisper on Apple Silicon (15–30% faster; optional for Turbo)
- [ ] Parakeet on the Neural Engine (CoreML through ONNX Runtime was 3–4x slower than CPU)

### App
- [x] Onboarding: welcome, permissions, model, hotkey
- [x] Dashboard, History (search, playback), Dictionary, Statistics, Settings
- [x] Light and dark themes
- [x] Update check against GitHub releases
- [ ] Launch at login

## Planned for a later v2 release
- [x] Import settings, dictionary and history from SpeakType 1 (automatic on first launch, or from Settings)
- [ ] Install updates in place (currently opens the release page)
- [x] Menu bar panel: dictate, today's stats, quick model/language/mic/mode switches, recent transcripts
- [ ] Hide the Dock icon when the window is closed
- [x] Signed and notarized macOS build, universal (Apple Silicon and Intel; Parakeet on Apple Silicon only)
- [ ] Signed Windows installer
- [x] CI builds for macOS, Windows and Linux on every tag

## New in SpeakType 2
- [ ] Windows build, tested
- [ ] Linux build, tested (X11 and Wayland)
- [ ] Single-modifier hotkeys on Windows and Linux
