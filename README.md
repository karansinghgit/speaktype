<div align="center">

<img src="speaktype/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="96" alt="SpeakType icon">

# SpeakType

**Talk instead of type, in any app. Free, open source, and 100% on your computer.**

[![Download for macOS](https://img.shields.io/badge/macOS-Download-111111?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/karansinghgit/speaktype/releases?q=v2&expanded=true)
[![Download for Windows](https://img.shields.io/badge/Windows-Download-111111?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/karansinghgit/speaktype/releases?q=v2&expanded=true)
[![Download for Linux](https://img.shields.io/badge/Linux-Download-111111?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/karansinghgit/speaktype/releases?q=v2&expanded=true)

[![Stars](https://img.shields.io/github/stars/karansinghgit/speaktype?style=flat-square&color=111111)](https://github.com/karansinghgit/speaktype/stargazers)
[![Downloads](https://img.shields.io/github/downloads/karansinghgit/speaktype/total?style=flat-square&color=111111)](https://github.com/karansinghgit/speaktype/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-111111?style=flat-square)](LICENSE)

<img src=".github/assets/speaktype.webp" alt="The SpeakType dashboard: 47,176 words transcribed, this week's activity and recent transcriptions" width="100%">

</div>

Hold <kbd>fn</kbd>, say what you want to write, and let go. Your words appear wherever your cursor is: Slack, email, your editor, a terminal, a prompt box. Cloud dictation apps send your voice to a server and charge a subscription for it. SpeakType runs the speech model on your own machine, so it costs nothing, works offline, and nothing you say ever leaves your computer.

## Why people switch to SpeakType

**🔒 Your voice stays on your computer.** No account, no cloud, no tracking. Pull the network cable and it still works.

**⚡ Faster than you can reach the keyboard.** Parakeet turns a 35-second ramble into punctuated text in under two seconds on an M3 Pro, and the model loads while you're still talking.

**🪶 Tiny.** About 15 MB to install. With a model loaded it uses around 285 MB of memory, and 0% CPU while it waits.

**🆓 Free. Actually free.** No trial, no word limits, no monthly plan. MIT licensed, so you can read every line.

**💻 macOS, Windows and Linux.** One app, with the same local models on every system.

**🌍 25+ languages.** Parakeet v3 covers 25 European languages, and Whisper covers 99.

## What's inside

- **Hold to talk or toggle.** On a Mac, use <kbd>fn</kbd> or a single key like right <kbd>⌘</kbd>. Any shortcut works on every system.
- **The best open models.** NVIDIA Parakeet v2 and v3 for speed, and OpenAI Whisper from Tiny to Large v3 Turbo for accuracy. SpeakType recommends one for your hardware.
- **Neural Engine acceleration** for Whisper on Apple Silicon.
- **Works in every app.** It pastes into whatever has focus, then puts your clipboard back the way it was.
- **A dictionary** for names, jargon and anything else it keeps getting wrong.
- **Cleaner text:** filler words like "um" and "uh" are removed, and punctuation is tidied up.
- **History with playback.** Copy past dictations again and replay their recordings.
- **Stats** on words dictated and typing time saved.
- **A recorder pill** with a live waveform, placed wherever you want it on screen.
- **A menu bar panel** to start dictating, switch model, language or microphone, and grab your latest dictations.

## Get started

**[Download SpeakType](https://github.com/karansinghgit/speaktype/releases?q=v2&expanded=true)** and pick the file for your system:

| System | File |
| --- | --- |
| macOS 13+ (Apple Silicon) | `SpeakType_…_aarch64.dmg` |
| Windows 10 and 11 | `SpeakType_…_x64-setup.exe` |
| Linux (Ubuntu, Debian) | `SpeakType_…_amd64.deb` |
| Linux (other distros) | `SpeakType_…_amd64.AppImage` |

Then:

1. Allow microphone and accessibility access when asked. SpeakType needs them to hear you and to paste.
2. Pick a model. SpeakType suggests one that runs well on your computer.
3. Hold your hotkey and start talking.

SpeakType 2 is new, so expect a few rough edges, and please [open an issue](https://github.com/karansinghgit/speaktype/issues) when you find one. The builds aren't signed by Apple or Microsoft yet, so the first launch needs one extra step:

- **macOS:** if it says Apple couldn't check the app, open **System Settings → Privacy & Security** and click **Open Anyway**.
- **Windows:** on the SmartScreen prompt, click **More info**, then **Run anyway**.

Looking for the previous Mac-only app? [SpeakType 1.3](https://github.com/karansinghgit/speaktype/releases/tag/v1.3.0) is still available.

## Contribute

SpeakType is growing fast, and there's plenty of room to help:

- **App core** in Rust: audio, speech engines, hotkeys and pasting on each system. The codebase is young and small, so it's a friendly place to learn Rust.
- **Interface** in React and TypeScript.
- **Product and design:** ideas, feedback and polish.
- **Mobile** in React Native. Coming soon.

Pick an [issue](https://github.com/karansinghgit/speaktype/issues), or open one to say what you'd like to work on. For anything bigger than a small fix, let's talk it through first.

## Credits

Speech recognition by [OpenAI Whisper](https://github.com/openai/whisper) through [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and [WhisperKit](https://github.com/argmaxinc/WhisperKit), and [NVIDIA Parakeet](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) through [ONNX Runtime](https://onnxruntime.ai) and [FluidAudio](https://github.com/FluidInference/FluidAudio).

## License

[MIT](LICENSE). Made by [2048 Labs](https://tryspeaktype.com).

<div align="center">

If SpeakType saves you some typing, a ⭐ helps other people find it.

</div>
