# Contributing to SpeakType

Thanks for helping out! This guide covers everything from a fresh machine to a merged pull request, on macOS, Windows and Linux. You don't need to know Rust or React already. The codebase is young and small, and it's a good place to learn either.

**Contents**

1. [Ways to help](#ways-to-help)
2. [How the app fits together](#how-the-app-fits-together)
3. [Set up your machine](#set-up-your-machine): [macOS](#macos) · [Windows](#windows) · [Linux](#linux)
4. [Run the app](#run-the-app)
5. [Test your changes](#test-your-changes)
6. [Make a pull request](#make-a-pull-request)
7. [Code guidelines](#code-guidelines)
8. [Troubleshooting](#troubleshooting)

---

## Ways to help

| Area | Stack | Examples |
| --- | --- | --- |
| **Frontend** | React, TypeScript, Tailwind | Screens, the recorder pill, the menu bar panel, screens for upcoming features |
| **App core** | Rust | Audio capture, speech models, hotkeys and pasting on each system, local post-processing models |
| **Windows and Linux** | Rust | Testing on real machines, single-key hotkeys, Wayland support, fixing anything that behaves differently from macOS |
| **Product and design** | | Bug reports, ideas, UX feedback, copy |
| **Mobile** | React Native | Coming soon |

You don't have to write code to help. A clear bug report from a Windows or Linux machine is one of the most useful things you can send.

**Before you start on something big,** [open an issue](https://github.com/karansinghgit/speaktype/issues) or comment on an existing one so we can agree on the approach. Small fixes can go straight to a pull request.

---

## How the app fits together

SpeakType 2 is one app for macOS, Windows and Linux, in [`desktop/`](desktop). It has two halves:

- **The app core** (`desktop/src-tauri/`, Rust) records audio, runs the speech models, listens for the hotkey, pastes text, and saves settings and history.
- **The interface** (`desktop/src/`, React) draws every window. It talks to the core through commands (`invoke`) and listens for events.

```
desktop/
├── src/                         Interface
│   ├── app/                     Main window shell, sidebar, routes
│   ├── screens/                 One folder per screen (dashboard, history, models, settings…)
│   ├── components/ui/           Shared building blocks: Button, Card, Section, Select…
│   ├── pill/  tray/             The recorder pill and menu bar panel windows
│   ├── lib/api.ts               Every command and type shared with the core
│   ├── styles/globals.css       Colors, type styles, radii, shadows
│   └── dev/browserPreview.ts    Sample data for running the UI in a browser
├── src-tauri/                   App core
│   ├── src/
│   │   ├── commands.rs          Commands the interface can call
│   │   ├── dictation.rs         Record → transcribe → paste, as a small state machine
│   │   ├── audio.rs  engine/    Microphone capture and the Whisper and Parakeet engines
│   │   ├── models.rs            Model catalog and downloads
│   │   ├── history.rs  settings.rs  legacy.rs (import from SpeakType 1)
│   │   └── platform/            Everything OS-specific
│   │       ├── macos/  windows/  linux/
│   └── examples/transcribe_wav.rs   Benchmark a model without the UI
├── ROADMAP.md                   What's done and what's next
└── scripts/release.mjs          Tags a release (maintainers)
```

Each folder in `platform/` exposes the same functions (hotkeys, pasting, permissions…), so the rest of the core never checks which OS it's on. To change how something works on one system, you usually only touch that system's folder.

> The Swift app in `speaktype/` is SpeakType 1, the previous macOS-only app. It only gets critical fixes. New work goes into `desktop/`.

---

## Set up your machine

Every system needs:

- **Git**
- **Node.js 22 or newer** ([nodejs.org](https://nodejs.org), or `nvm install 22`)
- **Rust**, the current stable version, installed with [rustup](https://rustup.rs). SpeakType needs at least 1.88.
- **CMake**, used to build the Whisper engine

Then clone the repo and install the interface's dependencies:

```bash
git clone https://github.com/<your-username>/speaktype.git
cd speaktype/desktop
npm install
```

The first build compiles the speech engines, which takes 5–15 minutes. Later builds only recompile what changed, usually in seconds.

### macOS

Requires macOS 13 or later. Apple Silicon and Intel both work for development.

1. Install Apple's build tools:
   ```bash
   xcode-select --install
   ```
2. Install CMake, Node and Rust. With [Homebrew](https://brew.sh):
   ```bash
   brew install cmake node
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```
3. Check everything is there:
   ```bash
   node -v && cargo -V && cmake --version
   ```

**Permissions while developing.** The first time you dictate, macOS asks for microphone access. For pasting and the <kbd>fn</kbd> hotkey, add the app under **System Settings → Privacy & Security → Accessibility**. In development that's the `SpeakType` binary in `desktop/src-tauri/target/debug/`, or the terminal you started it from. If pasting stops working after a rebuild, remove the entry and add it again: macOS sometimes treats a rebuilt binary as a new app.

### Windows

Windows 10 or 11, 64-bit.

1. Install **Visual Studio Build Tools 2022** from [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/) (under "Tools for Visual Studio"). In the installer, tick **Desktop development with C++**.
2. Install the rest with `winget`, in PowerShell:
   ```powershell
   winget install Rustlang.Rustup OpenJS.NodeJS.LTS Kitware.CMake LLVM.LLVM Git.Git
   ```
   Open a new terminal afterwards so the new tools are on your `PATH`.
3. Tell the Whisper engine's build where LLVM is:
   ```powershell
   [Environment]::SetEnvironmentVariable("LIBCLANG_PATH", "C:\Program Files\LLVM\bin", "User")
   ```
   Open a new terminal again.
4. Make sure Rust uses the MSVC toolchain, and check everything is there:
   ```powershell
   rustup default stable-msvc
   node -v; cargo -V; cmake --version; clang --version
   ```

WebView2, which draws the interface, comes with Windows 10 and 11. If the window stays blank, install the [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/).

**Tip:** clone into a short path like `C:\dev\speaktype`. Deep folders can hit Windows' path length limit during the first build.

### Linux

Any recent 64-bit distribution. Install the system libraries for yours, then Rust and Node.

**Ubuntu, Debian, Pop!_OS, Mint**

```bash
sudo apt update
sudo apt install -y build-essential curl wget file pkg-config cmake clang \
  libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev \
  libasound2-dev libxdo-dev libssl-dev patchelf
```

**Fedora**

```bash
sudo dnf group install -y "c-development"
sudo dnf install -y curl wget file cmake clang pkgconf-pkg-config \
  webkit2gtk4.1-devel libappindicator-gtk3-devel librsvg2-devel \
  alsa-lib-devel libxdo-devel openssl-devel
```

**Arch, Manjaro, EndeavourOS**

```bash
sudo pacman -S --needed base-devel curl wget file cmake clang \
  webkit2gtk-4.1 libappindicator-gtk3 librsvg alsa-lib xdotool openssl
```

Then install Rust and Node (or use your package manager's `nodejs` if it's version 22 or newer):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
nvm install 22
node -v && cargo -V && cmake --version
```

**X11 and Wayland.** On X11, the global hotkey and pasting work like on other systems. On Wayland:

- The global hotkey only fires while an X11 (XWayland) app has focus.
- Pasting needs a helper: `wtype` on Sway, Hyprland and KDE, or `ydotool` on GNOME. Install one with your package manager. Without either, the text is left on the clipboard.

Check which session you're on with `echo $XDG_SESSION_TYPE`. If you can, test changes to hotkeys or pasting on both.

---

## Run the app

All commands run from `desktop/`.

```bash
npm run app
```

This starts the full app with live reload. Changes to the interface appear instantly. Changes to Rust files rebuild and restart the app, which takes a few seconds.

To open the web inspector, right-click inside a window and choose **Inspect**. The core's logs print in the terminal, tagged by area, like `[hotkey]`, `[models]` or `[paste]`.

### Work on the interface in a browser

You don't need to build Rust at all for most design and frontend work:

```bash
npm run dev
```

Open [localhost:1420](http://localhost:1420). The interface runs with sample data from `src/dev/browserPreview.ts`. Add these to the URL to preview other states:

| Add | Shows |
| --- | --- |
| `?theme=dark` | Dark mode |
| `?onboarding=1` | Onboarding for a new user |
| `?onboarding=1&imported=1` | Onboarding after upgrading from SpeakType 1 |
| `?empty=1` | No history or stats yet |

Anything that needs the real core (recording, downloads, hotkeys) doesn't work in the browser.

### GPU acceleration

By default the app runs models on the CPU, so it builds everywhere. With an NVIDIA GPU and the [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads), or the [Vulkan SDK](https://vulkan.lunarg.com/) for other GPUs:

```bash
npm run app -- --features cuda     # or --features vulkan
```

### Where your data lives

| | macOS | Windows | Linux |
| --- | --- | --- | --- |
| Settings | `~/Library/Application Support/com.2048labs.speaktype/` | `%APPDATA%\com.2048labs.speaktype\` | `~/.config/com.2048labs.speaktype/` |
| History, recordings, models | same folder | same folder | `~/.local/share/com.2048labs.speaktype/` |

- **See onboarding again:** quit the app and delete `settings.json`.
- **Start completely fresh:** delete both folders. You'll have to download a model again.

---

## Test your changes

### Automated checks

Run these before opening a pull request. CI runs the same checks on macOS, Windows and Linux.

```bash
# Interface, from desktop/
npm run typecheck
npm test

# App core, from desktop/src-tauri/
cargo fmt
cargo clippy --all-targets -- -D warnings
cargo test
```

`clippy` must finish without warnings. CI treats warnings as errors.

**Writing tests:**

- **Rust:** tests live at the bottom of the file they test, in a `#[cfg(test)] mod tests` block. `dictation.rs`, `history.rs` and `legacy.rs` have good examples. Keep logic that decides things (like the dictation state machine) in plain functions, so it can be tested without a microphone or a window.
- **TypeScript:** put tests next to the file, named `*.test.ts`, like `src/lib/format.test.ts`. They run with [Vitest](https://vitest.dev).

### Test by hand

Automated tests can't press your hotkey or paste into another app. For anything that touches dictation, go through this list on your system:

**Dictation**
- [ ] Hold the hotkey, speak, release: the text appears in a text editor, a browser text field and a terminal.
- [ ] Toggle mode (Settings → Recording mode): press once to start and again to stop.
- [ ] <kbd>Esc</kbd> while recording stops without pasting, and the transcript still shows up in History.
- [ ] Pressing another key while holding the hotkey cancels the recording.
- [ ] With "Restore clipboard" on, whatever you had copied before is still on the clipboard afterwards.

**Recorder pill and menu bar**
- [ ] The pill appears while recording, shows a moving waveform and the elapsed time, and hides afterwards.
- [ ] Each pill position in Settings puts it in the right place, including on a second display.
- [ ] Clicking the menu bar or tray icon opens the panel, and dictation can start from there. On Linux, the icon shows a menu instead.

**Models**
- [ ] Download a small model (Whisper Base): progress shows, and cancelling works.
- [ ] Switch models: the next dictation uses the new one.
- [ ] Delete a model: it disappears and its disk space is freed.

**History and settings**
- [ ] A new dictation appears on the Dashboard and in History, and its recording plays.
- [ ] Settings survive quitting and reopening the app.

**Per system**

- **macOS:** the <kbd>fn</kbd> key and single-key hotkeys like right <kbd>⌘</kbd> work, <kbd>fn</kbd> doesn't open the emoji picker, and permission prompts appear during onboarding.
- **Windows:** a shortcut like <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd> works in Notepad, a browser and Windows Terminal. Dictating into an app running as administrator leaves the text on the clipboard instead of pasting, which is expected.
- **Linux:** test on X11, and on Wayland with `wtype` or `ydotool` installed. Pasting into a terminal should use <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd>.

In your pull request, say which systems you tested on. If you couldn't test one, that's fine, just say so.

### Benchmark a model

To measure transcription speed without the interface, from `desktop/src-tauri/`:

```bash
# Download a model into a folder
cargo run --release --example transcribe_wav -- download parakeet-tdt-v3 ./bench-models

# Transcribe a WAV file 3 times and print the timings
cargo run --release --example transcribe_wav -- parakeet-tdt-v3 ./bench-models clip.wav 3
```

Model ids are in `src/models.rs` (`parakeet-tdt-v3`, `base-en`, `large-v3-turbo`…). Include before and after numbers in any pull request that's meant to make transcription faster.

---

## Make a pull request

1. **Fork** the repo on GitHub and clone your fork.
2. **Branch off `main`:**
   ```bash
   git checkout main && git pull
   git checkout -b fix/linux-paste-in-terminals
   ```
   Name it `feat/…`, `fix/…`, `docs/…` or `ci/…`.
3. **Commit** in small steps. We use short, lowercase [conventional commit](https://www.conventionalcommits.org) messages:
   ```
   fix(v2): paste with Ctrl+Shift+V in Linux terminals
   feat(v2): show download speed on the AI Models screen
   ```
4. **Run the checks** in [Test your changes](#test-your-changes).
5. **Push and open a pull request** against `main`. In the description, cover:
   - what changed and why, and link the issue (`Fixes #123`)
   - which systems you tested on
   - a screenshot or short recording for anything visual
6. **CI runs automatically.** It checks the interface, lints and tests the core on all three systems, audits dependencies, and builds installers you can download from the run's summary page to try your change. A maintainer reviews once it's green.

Releases are handled by maintainers: `npm run release` tags a version, and CI publishes the installers.

---

## Code guidelines

### Rust

- **No warnings.** `cargo clippy --all-targets -- -D warnings` must pass.
- **No panics on user data.** Return `Result` and show the user a clear message. Don't use `unwrap()` on anything that can fail at runtime, like files, the network, audio devices or user input.
- **Explain every `unsafe` block** with a `// SAFETY:` comment saying why it's sound. Most `unsafe` code lives in `platform/`.
- **Keep OS-specific code in `platform/<os>/`.** When you add a function there, add it to all three systems, even if some of them just return "not supported".
- **Adding a command the interface can call:**
  1. Write it in `commands.rs`.
  2. Register it in the `invoke_handler` list in `lib.rs`.
  3. Add a typed wrapper in `src/lib/api.ts`.
  4. Add a sample response in `src/dev/browserPreview.ts`, so the browser preview keeps working.
- **Long work doesn't block the interface.** Commands are `async`, and anything slow (loading a model, transcribing) runs off the main thread.

### Interface

- **Use the shared components** in `src/components/ui/` (Button, Card, Section, SettingRow, Select…) before writing new ones.
- **Use the design tokens** from `src/styles/globals.css`: colors like `text-ink-secondary` and `bg-surface`, type styles like `type-title` and `type-body`, radii and shadows. Don't hard-code colors or font sizes. This keeps light and dark mode working and the app consistent.
- **Check both themes** (`?theme=dark`) and a narrow window before sending a visual change.

### Writing in the app

Buttons, labels and messages should be short and plain. Say what happens, like "Download", "Couldn't reach the microphone" or "Imported 21 transcriptions". Avoid jargon, and don't blame the user in error messages.

---

## Troubleshooting

**The first build takes forever.** That's normal: it compiles the speech engines, the interface framework and WebKit bindings once. It's much faster afterwards. On a machine with little memory, limit parallel jobs: `CARGO_BUILD_JOBS=2 npm run app`.

**`CMake` or `cmake` not found.** Install CMake (see your system's setup above) and open a new terminal.

**macOS: dictation records but nothing is pasted.** Grant Accessibility access (see [macOS](#macos)). After a rebuild, remove the old entry and add it again.

**macOS: the fn key does nothing.** Accessibility access is missing, or another app already uses <kbd>fn</kbd>. Try a different hotkey in Settings to narrow it down.

**Windows: `Unable to find libclang`.** `LIBCLANG_PATH` isn't set, or the terminal was opened before you set it. See step 3 in [Windows](#windows).

**Windows: `link.exe` not found or MSVC errors.** The C++ build tools are missing. Re-run the Visual Studio Build Tools installer and tick **Desktop development with C++**.

**Linux: `webkit2gtk-4.1` not found.** Your distribution's WebKit package is missing or too old. Install the packages listed for your distribution. Ubuntu 22.04 or newer is needed for `libwebkit2gtk-4.1-dev`.

**Linux on ARM64: the Whisper engine fails to compile with fp16 errors.** Build without native CPU tuning:
```bash
GGML_NATIVE=OFF GGML_CPU_ARM_ARCH=armv8.2-a+fp16 npm run app
```

**Linux: the tray icon doesn't show.** GNOME needs the [AppIndicator extension](https://extensions.gnome.org/extension/615/appindicator-support/).

**Linux: the hotkey doesn't work on Wayland.** It only fires while an X11 app has focus (see [Linux](#linux)). An X11 session is the most reliable option for now.

**Something else?** [Open an issue](https://github.com/karansinghgit/speaktype/issues) with your system, what you ran, and the full error output. Stuck setups are worth reporting too: they help us improve this guide.
