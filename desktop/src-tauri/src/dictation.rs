//! The dictation state machine: hotkey, record, transcribe, paste.
//!
//! All events go through one controller thread, so the session state has a
//! single owner and events are handled in the order they were sent, including
//! progress from transcription workers. This also keeps shortcut registration
//! out of the global shortcut plugin's event handler, which holds a lock while
//! it runs.
//!
//! What user input does is decided by [`decide`], a pure function, so it can be
//! tested without a microphone or windows.

use std::{
    mem,
    panic::{self, AssertUnwindSafe},
    sync::mpsc::{self, Sender},
    thread,
    time::Duration,
};

use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};

use crate::{
    AppState, LockExt,
    audio::{Captured, Recording},
    history::now_ms,
    paste::Paster,
    pill::{self, PillState},
    pipeline,
    platform::{self, HotkeyEvent},
    settings::RecordingMode,
};

const CANCEL_KEY: &str = "Escape";

const TRANSCRIBING: &str = "Transcribing...";
const STOPPING: &str = "Stopping transcription...";

/// How long status messages stay in the pill.
const ERROR_MESSAGE: Duration = Duration::from_millis(2000);
const NO_SPEECH_MESSAGE: Duration = Duration::from_millis(1500);
const STOPPING_MESSAGE: Duration = Duration::from_millis(800);

/// Broadcast to the UI as `dictation-state`.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "phase", rename_all = "camelCase")]
pub enum DictationState {
    Idle,
    #[serde(rename_all = "camelCase")]
    Recording {
        started_at_ms: u64,
    },
    Transcribing,
}

pub enum Event {
    HotkeyDown,
    HotkeyUp,
    /// Another key was pressed while a single-modifier hotkey was held.
    HotkeyInterrupted,
    /// Start or stop from the UI or tray, regardless of recording mode.
    Toggle,
    Escape,
    /// A transcription worker started or finished waiting for the model.
    Warming {
        session: u64,
        warming: bool,
    },
    Transcribed {
        session: u64,
        outcome: Outcome,
    },
    MessageExpired {
        generation: u64,
    },
    /// Settings changed: the pill may need to appear, hide or move.
    RefreshPill,
}

type Outcome = Result<String, pipeline::Error>;

/// Input from the user, as opposed to progress from the app itself.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Input {
    HotkeyDown,
    HotkeyUp,
    HotkeyInterrupted,
    Toggle,
    Escape,
}

/// The part of [`Phase`] that decides what input does.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Activity {
    /// Idle, or showing a status message.
    Idle,
    Recording {
        /// Started by pressing the hotkey, rather than from the UI or tray.
        by_hotkey: bool,
    },
    Transcribing,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Action {
    Nothing,
    Start {
        by_hotkey: bool,
    },
    /// Stops recording and transcribes. `cancelled` keeps the result from being pasted.
    Stop {
        cancelled: bool,
    },
    /// Stops recording and throws the audio away.
    Discard,
    /// Leaves the running transcription to finish in the background.
    CancelTranscription,
}

/// Decides what `input` does. `hotkey_down` tracks whether the hotkey is held,
/// so key repeat is ignored.
fn decide(input: Input, activity: Activity, mode: RecordingMode, hotkey_down: &mut bool) -> Action {
    let recording = matches!(activity, Activity::Recording { .. });
    match input {
        Input::HotkeyDown => {
            if mem::replace(hotkey_down, true) {
                return Action::Nothing;
            }
            match activity {
                Activity::Idle => Action::Start { by_hotkey: true },
                Activity::Recording { .. } if mode == RecordingMode::Toggle => {
                    Action::Stop { cancelled: false }
                }
                _ => Action::Nothing,
            }
        }
        Input::HotkeyUp => {
            let was_down = mem::replace(hotkey_down, false);
            if was_down && recording && mode == RecordingMode::Hold {
                Action::Stop { cancelled: false }
            } else {
                Action::Nothing
            }
        }
        Input::HotkeyInterrupted => {
            *hotkey_down = false;
            // The hotkey was part of a shortcut like ⌘C. A recording it started
            // wasn't a dictation, but one started from the UI carries on.
            match activity {
                Activity::Recording { by_hotkey: true } if mode == RecordingMode::Hold => {
                    Action::Discard
                }
                _ => Action::Nothing,
            }
        }
        Input::Toggle => match activity {
            Activity::Idle => Action::Start { by_hotkey: false },
            Activity::Recording { .. } => Action::Stop { cancelled: false },
            Activity::Transcribing => Action::Nothing,
        },
        Input::Escape => match activity {
            // Still transcribed and saved to history, but not pasted.
            Activity::Recording { .. } => Action::Stop { cancelled: true },
            // The transcription finishes in the background and lands in history.
            Activity::Transcribing => Action::CancelTranscription,
            Activity::Idle => Action::Nothing,
        },
    }
}

enum Phase {
    Idle,
    Recording {
        recording: Recording,
        by_hotkey: bool,
    },
    Transcribing {
        session: u64,
        /// Escape was pressed while recording.
        cancelled: bool,
    },
    /// A short status message before returning to idle.
    Message {
        generation: u64,
    },
}

impl Phase {
    fn activity(&self) -> Activity {
        match self {
            Phase::Idle | Phase::Message { .. } => Activity::Idle,
            Phase::Recording { by_hotkey, .. } => Activity::Recording {
                by_hotkey: *by_hotkey,
            },
            Phase::Transcribing { .. } => Activity::Transcribing,
        }
    }
}

#[derive(Clone)]
pub struct Controller {
    tx: Sender<Event>,
}

impl Controller {
    pub fn spawn(app: AppHandle) -> std::io::Result<Self> {
        let (tx, rx) = mpsc::channel();
        let controller = Self { tx };
        let mut session = Session {
            app,
            controller: controller.clone(),
            paster: Paster::spawn(),
            phase: Phase::Idle,
            hotkey_down: false,
            owns_cancel_key: false,
            next_id: 0,
        };
        thread::Builder::new()
            .name("dictation".into())
            .spawn(move || {
                for event in rx {
                    // A bug in one event shouldn't end dictation for the rest of the run.
                    let handled = panic::catch_unwind(AssertUnwindSafe(|| session.handle(event)));
                    if handled.is_err() {
                        eprintln!("[dictation] event handler panicked");
                    }
                }
            })?;
        Ok(controller)
    }

    pub fn send(&self, event: Event) {
        let _ = self.tx.send(event);
    }

    /// Registers the user's hotkey, replacing `previous` if given. Single
    /// modifier keys like "Fn" use the platform's own listener.
    ///
    /// Waits on the main thread, and must not be called from a shortcut
    /// handler: the plugin holds its lock while handlers run.
    pub fn register_hotkey(
        &self,
        app: &AppHandle,
        hotkey: &str,
        previous: Option<&str>,
    ) -> Result<(), String> {
        let shortcuts = app.global_shortcut();
        if let Some(previous) = previous {
            if platform::MODIFIER_HOTKEYS.contains(&previous) {
                platform::stop_modifier_hotkey();
            } else {
                let _ = shortcuts.unregister(previous);
            }
        }

        let controller = self.clone();
        if platform::MODIFIER_HOTKEYS.contains(&hotkey) {
            return platform::start_modifier_hotkey(
                hotkey,
                Box::new(move |event| {
                    controller.send(match event {
                        HotkeyEvent::Down => Event::HotkeyDown,
                        HotkeyEvent::Up => Event::HotkeyUp,
                        HotkeyEvent::Interrupted => Event::HotkeyInterrupted,
                    })
                }),
            );
        }
        shortcuts
            .on_shortcut(hotkey, move |_, _, event| {
                controller.send(match event.state {
                    ShortcutState::Pressed => Event::HotkeyDown,
                    ShortcutState::Released => Event::HotkeyUp,
                });
            })
            .map_err(|e| format!("Couldn't register {hotkey}: {e}"))
    }
}

struct Session {
    app: AppHandle,
    controller: Controller,
    paster: Paster,
    phase: Phase,
    hotkey_down: bool,
    /// Whether this session registered Escape, as opposed to the user's hotkey being Escape.
    owns_cancel_key: bool,
    next_id: u64,
}

impl Session {
    fn state(&self) -> tauri::State<'_, AppState> {
        self.app.state::<AppState>()
    }

    fn handle(&mut self, event: Event) {
        match event {
            Event::HotkeyDown => self.input(Input::HotkeyDown),
            Event::HotkeyUp => self.input(Input::HotkeyUp),
            Event::HotkeyInterrupted => self.input(Input::HotkeyInterrupted),
            Event::Toggle => self.input(Input::Toggle),
            Event::Escape => self.input(Input::Escape),
            Event::Warming { session, warming } => self.warming(session, warming),
            Event::Transcribed { session, outcome } => self.transcribed(session, outcome),
            Event::MessageExpired { generation } => {
                if matches!(self.phase, Phase::Message { generation: g } if g == generation) {
                    self.go_idle();
                }
            }
            Event::RefreshPill => {
                if matches!(self.phase, Phase::Idle) {
                    pill::place(&self.app, self.state().settings().pill_position);
                    self.go_idle();
                }
            }
        }
    }

    fn input(&mut self, input: Input) {
        let mode = self.state().settings().recording_mode;
        match decide(input, self.phase.activity(), mode, &mut self.hotkey_down) {
            Action::Nothing => {}
            Action::Start { by_hotkey } => self.start(by_hotkey),
            Action::Stop { cancelled } => self.stop(cancelled),
            Action::Discard => self.go_idle(),
            Action::CancelTranscription => self.flash(STOPPING, STOPPING_MESSAGE),
        }
    }

    fn start(&mut self, by_hotkey: bool) {
        let settings = self.state().settings();
        if settings.selected_model.is_empty() {
            return self.flash("No model selected", ERROR_MESSAGE);
        }
        if !self.state().models.is_downloaded(&settings.selected_model) {
            return self.flash("Model not downloaded", ERROR_MESSAGE);
        }

        let app = self.app.clone();
        let recording = Recording::start(&settings.input_device, move |level| {
            let _ = app.emit_to(pill::LABEL, "pill-level", level);
        });
        match recording {
            Ok(recording) => {
                let started_at_ms = now_ms();
                self.phase = Phase::Recording {
                    recording,
                    by_hotkey,
                };
                self.set_cancel_key(true);
                self.show(PillState::Recording { started_at_ms });
                self.broadcast(DictationState::Recording { started_at_ms });
                // Load the model while the user speaks, so it's ready on release.
                self.state().warm_up(&self.app, &settings.selected_model);
            }
            Err(e) => {
                eprintln!("[dictation] {e}");
                self.flash("Microphone unavailable", ERROR_MESSAGE);
            }
        }
    }

    fn stop(&mut self, cancelled: bool) {
        let Phase::Recording { recording, .. } = mem::replace(&mut self.phase, Phase::Idle) else {
            return;
        };
        let captured = match recording.finish() {
            Ok(captured) => captured,
            Err(e) => {
                eprintln!("[dictation] {e}");
                return self.flash("Recording failed", ERROR_MESSAGE);
            }
        };

        self.next_id += 1;
        let session = self.next_id;
        self.phase = Phase::Transcribing { session, cancelled };
        let message = if cancelled { STOPPING } else { TRANSCRIBING };
        self.show(PillState::Processing {
            message: message.into(),
        });
        self.broadcast(DictationState::Transcribing);

        let app = self.app.clone();
        let controller = self.controller.clone();
        let worker = thread::Builder::new()
            .name("transcription".into())
            .spawn(move || {
                let outcome = transcribe(&app, &controller, session, &captured);
                controller.send(Event::Transcribed { session, outcome });
            });
        if let Err(e) = worker {
            let error = pipeline::Error::Transcribe(format!("Couldn't start transcription: {e}"));
            self.transcribed(session, Err(error));
        }
    }

    fn warming(&mut self, session: u64, warming: bool) {
        // After Escape or a newer dictation the pill has moved on.
        let current = matches!(
            self.phase,
            Phase::Transcribing { session: s, cancelled: false, .. } if s == session
        );
        if !current {
            return;
        }
        self.show(if warming {
            PillState::Warming
        } else {
            PillState::Processing {
                message: TRANSCRIBING.into(),
            }
        });
    }

    fn transcribed(&mut self, session: u64, outcome: Outcome) {
        let Phase::Transcribing {
            session: current,
            cancelled,
        } = self.phase
        else {
            return;
        };
        if current != session {
            return;
        }

        match outcome {
            Ok(text) => {
                self.go_idle();
                if !cancelled {
                    let restore = self.state().settings().restore_clipboard;
                    self.paster.paste(text, restore);
                }
            }
            Err(e) => {
                if let Some(detail) = e.detail() {
                    eprintln!("[dictation] {detail}");
                }
                let duration = match e {
                    pipeline::Error::NoSpeech => NO_SPEECH_MESSAGE,
                    _ => ERROR_MESSAGE,
                };
                self.flash(e.message(), duration);
            }
        }
    }

    /// Shows a status message in the pill, then returns to idle.
    fn flash(&mut self, message: &str, duration: Duration) {
        self.next_id += 1;
        let generation = self.next_id;
        self.phase = Phase::Message { generation };
        self.set_cancel_key(false);
        self.show(PillState::Processing {
            message: message.into(),
        });
        self.broadcast(DictationState::Idle);
        let controller = self.controller.clone();
        let timer = thread::Builder::new()
            .name("pill-message".into())
            .spawn(move || {
                thread::sleep(duration);
                controller.send(Event::MessageExpired { generation });
            });
        if let Err(e) = timer {
            eprintln!("[dictation] {e}");
            self.go_idle();
        }
    }

    /// Returns to idle. Dropping a recording stops the microphone and discards its audio.
    fn go_idle(&mut self) {
        self.phase = Phase::Idle;
        self.set_cancel_key(false);
        self.show(PillState::Idle);
        self.broadcast(DictationState::Idle);
    }

    fn show(&self, state: PillState) {
        let settings = self.state().settings();
        let interactive = settings.always_show_pill && matches!(&state, PillState::Idle);
        pill::update(
            &self.app,
            state,
            settings.pill_position,
            settings.always_show_pill,
        );
        pill::set_interactive(&self.app, interactive);
    }

    fn broadcast(&self, state: DictationState) {
        let _ = self.app.emit("dictation-state", &state);
        crate::tray::show_state(&self.app, &state);
        *self.state().dictation_state.lock_unpoisoned() = state;
    }

    /// Escape is only claimed while a dictation is active, so other apps keep it otherwise.
    fn set_cancel_key(&mut self, active: bool) {
        if active == self.owns_cancel_key {
            return;
        }
        let shortcuts = self.app.global_shortcut();
        if !active {
            let _ = shortcuts.unregister(CANCEL_KEY);
            self.owns_cancel_key = false;
            return;
        }
        // Escape is the user's hotkey, which must stay registered.
        if shortcuts.is_registered(CANCEL_KEY) {
            return;
        }
        let controller = self.controller.clone();
        let result = shortcuts.on_shortcut(CANCEL_KEY, move |_, _, event| {
            if event.state == ShortcutState::Pressed {
                controller.send(Event::Escape);
            }
        });
        match result {
            Ok(()) => self.owns_cancel_key = true,
            Err(e) => eprintln!("[dictation] couldn't register Escape: {e}"),
        }
    }
}

/// Runs on a worker thread. Warming changes go through the controller, which
/// drops them once the session has moved on.
fn transcribe(
    app: &AppHandle,
    controller: &Controller,
    session: u64,
    captured: &Captured,
) -> Outcome {
    let on_warming = |warming| controller.send(Event::Warming { session, warming });
    // Without an outcome the session would stay transcribing until Escape.
    panic::catch_unwind(AssertUnwindSafe(|| {
        pipeline::run(app, &captured.samples, captured.duration_secs, on_warming)
    }))
    .unwrap_or_else(|_| Err(pipeline::Error::Transcribe("The engine crashed".into())))
    .map(|item| item.transcript)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Runs `inputs` from `activity`, returning each action.
    fn run(activity: Activity, mode: RecordingMode, inputs: &[Input]) -> Vec<Action> {
        let mut hotkey_down = false;
        inputs
            .iter()
            .map(|&input| decide(input, activity, mode, &mut hotkey_down))
            .collect()
    }

    #[test]
    fn hold_mode_records_while_the_hotkey_is_held() {
        let mut down = false;
        let mode = RecordingMode::Hold;
        assert_eq!(
            decide(Input::HotkeyDown, Activity::Idle, mode, &mut down),
            Action::Start { by_hotkey: true }
        );
        let recording = Activity::Recording { by_hotkey: true };
        // Key repeat while held does nothing.
        assert_eq!(
            decide(Input::HotkeyDown, recording, mode, &mut down),
            Action::Nothing
        );
        assert_eq!(
            decide(Input::HotkeyUp, recording, mode, &mut down),
            Action::Stop { cancelled: false }
        );
        assert!(!down);
    }

    #[test]
    fn toggle_mode_stops_on_the_next_press() {
        let mode = RecordingMode::Toggle;
        let recording = Activity::Recording { by_hotkey: true };
        assert_eq!(
            run(recording, mode, &[Input::HotkeyDown, Input::HotkeyUp]),
            [Action::Stop { cancelled: false }, Action::Nothing]
        );
        assert_eq!(
            run(Activity::Idle, mode, &[Input::HotkeyDown, Input::HotkeyUp])[1],
            Action::Nothing
        );
    }

    #[test]
    fn a_release_without_a_press_is_ignored() {
        let recording = Activity::Recording { by_hotkey: false };
        assert_eq!(
            run(recording, RecordingMode::Hold, &[Input::HotkeyUp]),
            [Action::Nothing]
        );
    }

    #[test]
    fn a_shortcut_discards_only_recordings_the_hotkey_started() {
        let mode = RecordingMode::Hold;
        let inputs = [Input::HotkeyDown, Input::HotkeyInterrupted, Input::HotkeyUp];
        assert_eq!(
            run(Activity::Recording { by_hotkey: true }, mode, &inputs),
            [Action::Nothing, Action::Discard, Action::Nothing]
        );
        // Recording from the tray, then pressing ⌘Tab with ⌘ as the hotkey.
        assert_eq!(
            run(Activity::Recording { by_hotkey: false }, mode, &inputs),
            [Action::Nothing, Action::Nothing, Action::Nothing]
        );
        assert_eq!(
            run(
                Activity::Recording { by_hotkey: true },
                RecordingMode::Toggle,
                &[Input::HotkeyInterrupted]
            ),
            [Action::Nothing]
        );
    }

    #[test]
    fn the_hotkey_does_nothing_while_transcribing() {
        for mode in [RecordingMode::Hold, RecordingMode::Toggle] {
            assert_eq!(
                run(
                    Activity::Transcribing,
                    mode,
                    &[Input::HotkeyDown, Input::HotkeyUp]
                ),
                [Action::Nothing, Action::Nothing]
            );
        }
    }

    #[test]
    fn toggle_starts_stops_and_waits_for_transcription() {
        let mode = RecordingMode::Hold;
        assert_eq!(
            run(Activity::Idle, mode, &[Input::Toggle]),
            [Action::Start { by_hotkey: false }]
        );
        assert_eq!(
            run(
                Activity::Recording { by_hotkey: false },
                mode,
                &[Input::Toggle]
            ),
            [Action::Stop { cancelled: false }]
        );
        assert_eq!(
            run(Activity::Transcribing, mode, &[Input::Toggle]),
            [Action::Nothing]
        );
    }

    #[test]
    fn escape_cancels_whatever_is_running() {
        let mode = RecordingMode::Hold;
        assert_eq!(
            run(
                Activity::Recording { by_hotkey: false },
                mode,
                &[Input::Escape]
            ),
            [Action::Stop { cancelled: true }]
        );
        assert_eq!(
            run(Activity::Transcribing, mode, &[Input::Escape]),
            [Action::CancelTranscription]
        );
        assert_eq!(
            run(Activity::Idle, mode, &[Input::Escape]),
            [Action::Nothing]
        );
    }
}
