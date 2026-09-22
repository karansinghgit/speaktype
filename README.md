<div align="center">

<img src=".github/assets/icon.png" width="112" alt="SpeakType icon">

# SpeakType

**Talk instead of type, in any app. Free, open source, and 100% on your computer.**

[![Download for macOS](https://img.shields.io/badge/macOS-Download-111111?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/latest)
[![Download for Windows](https://img.shields.io/badge/Windows-Download-111111?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/latest)
[![Download for Linux](https://img.shields.io/badge/Linux-Download-111111?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/latest)

[![Stars](https://img.shields.io/github/stars/karansinghgit/speaktype?style=flat-square&color=111111)](https://github.com/karansinghgit/speaktype/stargazers)
[![Downloads](https://img.shields.io/github/downloads/karansinghgit/speaktype/total?style=flat-square&color=111111)](https://github.com/karansinghgit/speaktype/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-111111?style=flat-square)](LICENSE)

<img src=".github/assets/speaktype.webp" alt="The SpeakType dashboard: 47,176 words transcribed, this week's activity and recent transcriptions" width="100%">

</div>

## What is SpeakType?

SpeakType lets you type with your voice. Hold a key, say what you want to write, and let go. Your words appear wherever your cursor is: an email, a chat, a document, a code editor, anywhere.

Most voice typing apps send your recordings to a company's servers and charge a monthly fee. SpeakType does all the work on your own computer, so it's **free**, it **works without internet**, and **nothing you say ever leaves your computer**.

## How it works

1. **Install SpeakType** and open it.
2. **Download a speech model** when SpeakType asks. This is the part that turns your voice into text. It's a one-time download of 75 MB to 1.6 GB, and SpeakType suggests one that suits your computer.
3. **Hold your shortcut and talk.** Click into any text box, hold <kbd>fn</kbd> on a Mac or <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Space</kbd> on Windows and Linux, speak, and let go. You can change the shortcut in Settings.

## Why people use it

|  | SpeakType | Typical voice typing apps |
| --- | --- | --- |
| **Cost** | Free, with no limits | Monthly subscription |
| **Your recordings** | Stay on your computer | Uploaded to the company's servers |
| **Without internet** | Works | Doesn't work |
| **Account** | Not needed | Required |

- **⚡ Fast.** A 35-second ramble becomes neat, punctuated text in under two seconds.
- **🪶 Light.** A 15 MB install that stays out of the way while you're not talking.
- **⌨️ Works in every app.** It types into whatever you're using, and puts back anything you had copied.
- **🌍 Many languages.** Up to 99 languages, depending on the model you pick.
- **📖 Gets your words right.** Teach it names and terms it mishears, and filler words like "um" are removed.
- **🕘 Keeps a history.** Copy and replay past dictations, and see how much typing you've saved.

## Download

**[Go to the downloads page](https://github.com/karansinghgit/speaktype/releases/latest)** and click the file for your computer:

| Your computer | Download this file |
| --- | --- |
| **Mac**, Apple Silicon or Intel, macOS 13 or later | the file ending in `.dmg` |
| **Windows** 10 or 11 | the file ending in `-setup.exe` |
| **Linux:** Ubuntu, Debian, Mint or Pop!_OS | the file ending in `.deb` |
| **Linux:** Fedora, RHEL or openSUSE | the file ending in `.rpm` |
| **Linux:** any other distribution | the file ending in `.AppImage` |

### Installing

**Mac**
1. Open the `.dmg` file and drag SpeakType into your Applications folder.
2. Open SpeakType. When asked, allow microphone access (so it can hear you) and accessibility access (so it can type for you).

**Windows**
1. Run the `-setup.exe` file.
2. If a blue "Windows protected your PC" box appears, click **More info**, then **Run anyway**. You only need to do this once.

**Linux**
- **`.deb`:** double-click it to install with your software center, or run `sudo apt install ./SpeakType_*.deb`.
- **`.rpm`:** double-click it, or run `sudo dnf install ./SpeakType-*.rpm`.
- **`.AppImage`:** make it runnable with `chmod +x SpeakType_*.AppImage`, then double-click it.

The extra step on Windows is there because the Windows app isn't signed by Microsoft yet. That's coming soon.

## Questions

<details>
<summary><b>Is it really free?</b></summary>

Yes. There's no trial, no word limit and no paid plan. SpeakType is open source under the MIT license, so anyone can read or reuse the code.

</details>

<details>
<summary><b>Does anything get sent over the internet?</b></summary>

No. Your voice is turned into text on your computer. SpeakType only goes online to download speech models when you ask it to, and to check for new versions, which you can turn off in Settings.

</details>

<details>
<summary><b>Which model should I pick?</b></summary>

The one SpeakType recommends is a good start. Roughly: smaller models are quicker and use less memory, and larger ones make fewer mistakes. **Parakeet** models are very fast and cover English plus 24 other European languages. They aren't available on Intel Macs. **Whisper** models cover 99 languages. You can download several and switch any time.

</details>

<details>
<summary><b>Where are my recordings and history kept?</b></summary>

Only on your computer. You can delete single dictations or clear everything from the History screen.

</details>

<details>
<summary><b>I used the old Mac app. Do I lose my history?</b></summary>

No. SpeakType 1 offers SpeakType 2 as an update, and the first time you open it, your history, dictionary and settings come with you. You'll need to download a speech model again, since SpeakType 2 uses a different kind. If you'd rather stay on the old app, [SpeakType 1.3](https://github.com/karansinghgit/speaktype/releases/tag/v1.3.0) remains available.

</details>

<details>
<summary><b>Something isn't working</b></summary>

SpeakType 2 is new, and Windows and Linux support is especially young. Please [open an issue](https://github.com/karansinghgit/speaktype/issues) describing what happened and which computer you're on. It helps a lot.

</details>

## What's next

- **Smarter cleanup, still private:** an optional step that tidies up and formats what you said, using an AI model on your computer.
- **iPhone and Android:** a SpeakType keyboard, with optional syncing between your devices.
- **Words as you speak**, instead of after you stop.
- **A signed Windows app**, so installing takes no extra steps.

The **[roadmap](ROADMAP.md)** has the rest: what's being worked on now, what's coming later, and what SpeakType will never do.

## Help build SpeakType

Everyone is welcome, and you don't have to write code. Bug reports, ideas and design feedback all help.

| If you know… | You could work on… |
| --- | --- |
| **React and TypeScript** | The app's screens, the recording bubble and the menu bar panel |
| **Rust**, or want to learn it | Audio, speech models, shortcuts and typing on Mac, Windows and Linux |
| **Design or product** | Feedback, ideas and polish |
| **React Native** | The upcoming iPhone and Android app |

The project is new and the code is small and easy to find your way around, so it's a friendly place to learn. People who use Windows or Linux every day are especially welcome.

Start with the **[contributing guide](CONTRIBUTING.md)**. It explains how to set up your computer, run and test SpeakType, and send your first change.

---

<div align="center">

**If SpeakType saves you some typing, a star helps other people find it.**

[![Star SpeakType on GitHub](https://img.shields.io/github/stars/karansinghgit/speaktype?style=for-the-badge&logo=github&label=Star%20SpeakType&color=39f27a&labelColor=111111)](https://github.com/karansinghgit/speaktype)

</div>

<sub>Speech recognition by [OpenAI Whisper](https://github.com/openai/whisper) and [NVIDIA Parakeet](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), running on [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [ONNX Runtime](https://onnxruntime.ai), [WhisperKit](https://github.com/argmaxinc/WhisperKit) and [FluidAudio](https://github.com/FluidInference/FluidAudio). [MIT licensed](LICENSE).</sub>
