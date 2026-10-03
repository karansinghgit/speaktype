# SpeakType 2

The cross-platform SpeakType app for macOS, Windows and Linux. It's developed alongside SpeakType 1 (`speaktype/`) and replaces it once everything in [ROADMAP.md](ROADMAP.md) is done.

## Develop

Requires Node 22+, a current stable Rust toolchain and CMake. On Linux, also install the system libraries listed in `.github/actions/setup-desktop-build/action.yml`.

```sh
npm install
npm run app        # run with live reload
npm run app:build  # build installers into src-tauri/target/release/bundle
```

To design screens without the native app, run `npm run dev` and open http://localhost:1420. The UI runs with sample data (add `?theme=dark` or `?onboarding=1` to the URL).

## Check

```sh
npm run typecheck && npm test                 # UI
cd src-tauri && cargo fmt --check \
  && cargo clippy --all-targets -- -D warnings \
  && cargo test                               # app core
```

Benchmark a downloaded model on an audio file:

```sh
cd src-tauri
cargo run --release --example transcribe_wav -- parakeet-tdt-v3 "<models folder>" clip.wav
```

## Release

```sh
npm run release          # tags the next alpha, e.g. v2.0.0-alpha.5, and pushes it
npm run release -- beta  # or the next beta
```

Releasing needs the [GitHub CLI](https://cli.github.com), signed in with `gh auth login`. The script creates the release on GitHub, and CI attaches the installers to it.

Every push and pull request that touches `desktop/` runs `.github/workflows/desktop.yml`:
- type checks, tests and a production build of the UI
- format, lint and tests of the app core on macOS, Windows and Linux
- a dependency audit
- installers for all three systems, uploaded as workflow artifacts

## Privacy & Telemetry

SpeakType includes an optional, privacy-focused telemetry system that is **disabled by default**:
- **Strictly opt-in:** No diagnostics or metrics leave your computer unless you explicitly turn on **Anonymous telemetry** in **Settings → Privacy & Diagnostics**.
- **No speech or text:** Audio recordings, transcripts, and personal data are never collected. The payload contains only high-level system information (OS, architecture, kernel, desktop environment), model name, and dictation success/error counters.
- **Anonymous identifier:** Reports are associated with a random UUID v4 that has no connection to your hardware or identity. You can rotate/reset this identifier at any time with one click in Settings.
- **Full transparency:** You can click **View current payload** in Settings to inspect the live JSON payload, or enable **Show telemetry payload in UI** to review it before exit.
- **Endpoint configuration:** Telemetry is sent via HTTP POST to `https://telemetry.speaktype.com/api/v1/telemetry`. This can be redirected using the `SPEAKTYPE_TELEMETRY_ENDPOINT` or `SPEAKTYPE_TELEMETRY_URL` environment variables.

## Layout

- `src/` UI. Colors, radii, shadows and type styles all come from `src/styles/globals.css`.
- `src-tauri/src/` app core: audio, transcription engines, dictation, paste, history, models, telemetry.
- `src-tauri/src/platform/{macos,windows,linux}/` everything OS-specific, one folder per OS with the same functions.
