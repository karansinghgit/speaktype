# Roadmap

What SpeakType is working on, and what it isn't. Dates are deliberately absent: this is a small project, and the order matters more than the calendar.

Anything here can move if enough people ask. The best way to push something up is to comment on its issue, or [open one](https://github.com/karansinghgit/speaktype/issues/new/choose).

## Just shipped: SpeakType 2.0

One app for **macOS, Windows and Linux**, rebuilt from scratch.

- The same local models on every system, with nothing leaving your computer.
- About 15 MB installed, roughly 285 MB of memory with a model loaded.
- A new design, a menu bar panel, and a signed Mac app that runs on Apple Silicon and Intel.
- Upgrading from SpeakType 1 brings your history, dictionary and settings with you.

## Now

The current focus, in order.

- **Make Windows and Linux solid.** They're brand new and barely tested outside CI. Anyone who can run [the test pass](https://github.com/karansinghgit/speaktype/issues/164) moves this along fastest.
- **Updates that install themselves.** Today SpeakType 2 sends you to the release page. SpeakType 1 installed updates for you, and v2 should too.
- **Your recordings, your choice.** A setting to keep transcripts without saving the audio ([#114](https://github.com/karansinghgit/speaktype/issues/114)).
- **The rough edges from your reports:** model loading that can hang ([#158](https://github.com/karansinghgit/speaktype/issues/158)), a microphone that goes quiet after a device change ([#157](https://github.com/karansinghgit/speaktype/issues/157)), no disk space check before a download ([#159](https://github.com/karansinghgit/speaktype/issues/159)).

## Next

- **Cleanup with a local AI model** ([#118](https://github.com/karansinghgit/speaktype/issues/118)). An optional pass that tidies up what you said: fix the odd word, format a list, match the tone of where you're writing. It runs on your computer, through Ollama or any compatible local endpoint, and your text is never sent anywhere. Off by default, and your raw transcript stays if it fails.
- **A dictionary that learns** ([#151](https://github.com/karansinghgit/speaktype/issues/151)). When you correct a word SpeakType keeps getting wrong, it should remember, rather than making you add the rule by hand.
- **Words as you speak** ([#112](https://github.com/karansinghgit/speaktype/issues/112)). Text appearing while you talk, instead of after you stop. The biggest change to how dictation feels, and the hardest to get right.
- **Wayland support that isn't a compromise** ([#163](https://github.com/karansinghgit/speaktype/issues/163)). Today the hotkey only fires while an older-style app has focus. Using the desktop portals fixes the hotkey and typing for every Linux user.
- **Small things people keep asking for:** launch at login, hiding the Dock icon on Mac, switching model by right-clicking the pill, pausing music while you record ([#63](https://github.com/karansinghgit/speaktype/issues/63)).

## Later

Wanted, but not started.

- **SpeakType on your phone.** An iOS and Android keyboard, with optional sync between your devices. This is the one feature that would need accounts, and it would stay optional.
- **Flathub** ([#163](https://github.com/karansinghgit/speaktype/issues/163)), so Linux gets updates and a listing people browse, instead of a download link.
- **A signed Windows installer,** so the SmartScreen warning goes away.
- **Who said what** ([#80](https://github.com/karansinghgit/speaktype/issues/80)), labelling speakers when transcribing a recording with several people in it.
- **Voice commands,** such as "scratch that" or "new paragraph", handled as you speak.

## Not planned

- **Cloud transcription.** The whole point is that your voice stays on your computer.
- **Accounts for the desktop app.** Nothing here needs one.
- **Paid tiers.** SpeakType is free and stays free.
- **Telemetry.** We don't collect usage data, and won't.

## Helping

Everything above is up for grabs, and most of it doesn't need Rust. The **[contributing guide](CONTRIBUTING.md)** covers setting up on macOS, Windows or Linux, and issues tagged [good first issue](https://github.com/karansinghgit/speaktype/labels/good%20first%20issue) are the gentlest way in.

The single most useful thing right now: run SpeakType on Windows or Linux and say what broke.
