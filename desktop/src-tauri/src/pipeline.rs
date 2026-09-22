//! Audio in, cleaned-up text out: shared by dictation and file transcription.

use std::{
    fmt,
    path::{Path, PathBuf},
    sync::MutexGuard,
};

use tauri::{AppHandle, Emitter, Manager};

use crate::{
    AppState, LockExt,
    engine::Engine,
    history::{self, HistoryItem},
    llm, media, models,
    settings::Settings,
    text,
};

/// What the pipeline is doing, for the pill.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// Waiting for the model to load.
    Warming,
    Transcribing,
    /// Waiting for the LLM to clean up the transcript.
    Polishing,
}

#[derive(Debug)]
pub enum Error {
    NoModel,
    ModelLoad(String),
    Transcribe(String),
    NoSpeech,
}

impl Error {
    /// Short message for the pill and the UI.
    pub fn message(&self) -> &'static str {
        match self {
            Error::NoModel => "No model selected",
            Error::ModelLoad(_) => "Model load failed",
            Error::Transcribe(_) => "Transcription failed",
            Error::NoSpeech => "No speech detected",
        }
    }

    /// The underlying engine error, for logs and the Transcribe Audio screen.
    pub fn detail(&self) -> Option<&str> {
        match self {
            Error::ModelLoad(e) | Error::Transcribe(e) => Some(e),
            Error::NoModel | Error::NoSpeech => None,
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.detail() {
            Some(detail) => write!(f, "{}: {detail}", self.message()),
            None => f.write_str(self.message()),
        }
    }
}

impl std::error::Error for Error {}

/// Transcribes 16 kHz mono audio with the selected model, saves the recording
/// and the result to history, and returns the history item.
///
/// `on_status` is called with [`Status::Warming`] before the model starts
/// loading and [`Status::Transcribing`] once it is done, whether or not loading
/// succeeded, then with [`Status::Polishing`] if the LLM is called.
pub fn run(
    app: &AppHandle,
    samples: &[f32],
    duration_secs: f64,
    on_status: impl Fn(Status),
) -> Result<HistoryItem, Error> {
    let state = app.state::<AppState>();
    let settings = state.settings();
    let model = models::find(&settings.selected_model)
        .filter(|m| state.models.is_downloaded(m.id))
        .ok_or(Error::NoModel)?;

    let mut engine = lock_engine(&state, &on_status);
    if engine.loaded_model() != Some(model.id) {
        on_status(Status::Warming);
        let loaded = state.load_model(app, &mut engine, model);
        on_status(Status::Transcribing);
        loaded.map_err(Error::ModelLoad)?;
    }
    let raw = engine
        .transcribe(samples, &settings.language)
        .map_err(Error::Transcribe)?;
    drop(engine);

    let text = process_text(&raw, &settings, |text| {
        on_status(Status::Polishing);
        llm::polish(text, &llm::Config::from_settings(&settings))
    });
    if text.is_empty() {
        return Err(Error::NoSpeech);
    }

    // The WAV is written without holding the history lock, so the UI can still
    // read history meanwhile.
    let recordings_dir = state
        .history
        .lock_unpoisoned()
        .recordings_dir()
        .to_path_buf();
    let audio_path = save_recording(&recordings_dir, samples);
    let added = state
        .history
        .lock_unpoisoned()
        .add(&text, duration_secs, model.name, audio_path);
    let _ = app.emit("history-changed", ());

    // Saving is best effort: the text is still returned if the disk write failed.
    let item = match added {
        Ok(item) => item,
        Err(e) => {
            eprintln!("[history] couldn't save transcript: {e}");
            None
        }
    };
    Ok(item.unwrap_or_else(|| HistoryItem {
        id: String::new(),
        created_at: history::now_ms(),
        word_count: text.split_whitespace().count(),
        transcript: text,
        duration_secs,
        model: model.name.into(),
        audio_path: None,
    }))
}

/// Turns the engine's raw output into the text to paste: engine cleanup, then
/// the LLM if it's on, then the dictionary and trailing punctuation.
///
/// `polish` is only called when the LLM is on and there is text to send. If it
/// fails, the cleaned-up transcript is used as if the LLM were off.
fn process_text(
    raw: &str,
    settings: &Settings,
    polish: impl FnOnce(&str) -> Result<String, String>,
) -> String {
    let text = text::normalize_transcription(raw, settings.auto_edit);
    let text = if settings.llm_enabled && !text.is_empty() {
        polish(&text).unwrap_or_else(|e| {
            eprintln!("[llm] {e}; using the original transcript");
            text
        })
    } else {
        text
    };
    text::finish(
        &text,
        &text::Options {
            smart_trailing_punctuation: settings.smart_trailing_punctuation,
            dictionary: &settings.dictionary,
        },
    )
}

/// If a warm-up holds the engine, the model is still loading, so report that while waiting.
fn lock_engine<'a>(state: &'a AppState, on_status: &impl Fn(Status)) -> MutexGuard<'a, Engine> {
    if let Some(engine) = state.engine.try_lock_unpoisoned() {
        return engine;
    }
    on_status(Status::Warming);
    let engine = state.engine.lock_unpoisoned();
    on_status(Status::Transcribing);
    engine
}

fn save_recording(dir: &Path, samples: &[f32]) -> Option<PathBuf> {
    let path = dir.join(format!("recording-{}.wav", history::now_ms()));
    match media::write_wav(&path, samples) {
        Ok(()) => Some(path),
        Err(e) => {
            eprintln!("[history] couldn't save recording: {e}");
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;

    use super::{Error, Settings, process_text};
    use crate::text::DictionaryEntry;

    fn settings(llm_enabled: bool) -> Settings {
        Settings {
            llm_enabled,
            dictionary: vec![DictionaryEntry {
                id: "1".into(),
                trigger: "speak type".into(),
                replacement: "SpeakType".into(),
                is_enabled: true,
                match_whole_word: true,
            }],
            ..Settings::default()
        }
    }

    #[test]
    fn llm_off_never_calls_it() {
        let text = process_text("I use speak type.", &settings(false), |_| {
            panic!("the LLM is off")
        });
        assert_eq!(text, "I use SpeakType.");
    }

    #[test]
    fn llm_reply_is_used_and_the_dictionary_still_applies_to_it() {
        // The LLM recapitalizes the trigger; matching ignores case, so it still applies.
        let text = process_text("i use speak type", &settings(true), |_| {
            Ok("I use Speak Type.".into())
        });
        assert_eq!(text, "I use SpeakType.");
    }

    #[test]
    fn smart_punctuation_still_applies_to_the_llm_reply() {
        let text = process_text("hello", &settings(true), |_| Ok("Hello.".into()));
        assert_eq!(text, "Hello");
    }

    #[test]
    fn llm_failure_falls_back_to_the_original_transcript() {
        let text = process_text("I use speak type.", &settings(true), |_| {
            Err("connection refused".into())
        });
        assert_eq!(text, "I use SpeakType.");
    }

    #[test]
    fn llm_sees_the_cleaned_transcript_before_the_dictionary() {
        let sent = RefCell::new(String::new());
        process_text("[BLANK_AUDIO] I use speak type", &settings(true), |text| {
            *sent.borrow_mut() = text.to_string();
            Ok(text.to_string())
        });
        assert_eq!(*sent.borrow(), "I use speak type");
    }

    #[test]
    fn llm_is_skipped_when_there_is_no_speech() {
        let text = process_text("[BLANK_AUDIO]", &settings(true), |_| {
            panic!("nothing to send")
        });
        assert!(text.is_empty());
    }

    #[test]
    fn errors_show_their_detail_when_they_have_one() {
        assert_eq!(Error::NoModel.to_string(), "No model selected");
        assert_eq!(Error::NoSpeech.to_string(), "No speech detected");
        assert_eq!(
            Error::ModelLoad("file is corrupt".into()).to_string(),
            "Model load failed: file is corrupt"
        );
        assert_eq!(
            Error::Transcribe("out of memory".into()).to_string(),
            "Transcription failed: out of memory"
        );
    }

    #[test]
    fn short_messages_leave_out_the_detail() {
        let error = Error::Transcribe("out of memory".into());
        assert_eq!(error.message(), "Transcription failed");
        assert_eq!(error.detail(), Some("out of memory"));
        assert_eq!(Error::NoSpeech.detail(), None);
    }
}
