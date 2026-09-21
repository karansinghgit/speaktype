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
    media, models, text,
};

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
/// `on_warming` is called with `true` before the model starts loading and
/// `false` once it is done, whether or not loading succeeded.
pub fn run(
    app: &AppHandle,
    samples: &[f32],
    duration_secs: f64,
    on_warming: impl Fn(bool),
) -> Result<HistoryItem, Error> {
    let state = app.state::<AppState>();
    let settings = state.settings();
    let model = models::find(&settings.selected_model)
        .filter(|m| state.models.is_downloaded(m.id))
        .ok_or(Error::NoModel)?;

    let mut engine = lock_engine(&state, &on_warming);
    if engine.loaded_model() != Some(model.id) {
        on_warming(true);
        let loaded = state.load_model(app, &mut engine, model);
        on_warming(false);
        loaded.map_err(Error::ModelLoad)?;
    }
    let raw = engine
        .transcribe(samples, &settings.language)
        .map_err(Error::Transcribe)?;
    drop(engine);

    let text = text::process(
        &raw,
        &text::Options {
            auto_edit: settings.auto_edit,
            smart_trailing_punctuation: settings.smart_trailing_punctuation,
            dictionary: &settings.dictionary,
        },
    );
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

/// If a warm-up holds the engine, the model is still loading, so report that while waiting.
fn lock_engine<'a>(state: &'a AppState, on_warming: &impl Fn(bool)) -> MutexGuard<'a, Engine> {
    if let Some(engine) = state.engine.try_lock_unpoisoned() {
        return engine;
    }
    on_warming(true);
    let engine = state.engine.lock_unpoisoned();
    on_warming(false);
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
    use super::{Error, save_recording};
    use crate::history::History;
    use std::{fs, path::PathBuf};

    struct TempDir(PathBuf);

    impl TempDir {
        fn new() -> Self {
            let dir = std::env::temp_dir().join(format!("speaktype-test-{}", uuid::Uuid::new_v4()));
            fs::create_dir_all(&dir).unwrap();
            Self(dir)
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn disabled_audio_saving_keeps_transcript_and_stats_without_creating_recordings() {
        let dir = TempDir::new();
        let mut history = History::load(&dir.0);
        let audio_path = save_recording(history.recordings_dir(), &[0.1; 160], false);
        assert_eq!(audio_path, None);
        assert!(!history.recordings_dir().exists());

        let item = history.add("hello world", 0.01, "Tiny", audio_path).unwrap().unwrap();
        let reloaded = History::load(&dir.0);
        assert_eq!(reloaded.items()[0].id, item.id);
        assert_eq!(reloaded.items()[0].transcript, "hello world");
        assert_eq!(reloaded.items()[0].audio_path, None);
        assert_eq!(reloaded.stats().len(), 1);
        let stats = serde_json::to_value(reloaded.stats()).unwrap();
        assert_eq!(stats[0]["wordCount"], 2);
        assert!(!history.recordings_dir().exists());
    }

    #[test]
    fn disabling_audio_saving_preserves_existing_recordings() {
        let dir = TempDir::new();
        let recordings = dir.0.join("recordings");
        let path = save_recording(&recordings, &[0.1; 160], true).unwrap();
        let reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert_eq!(reader.len(), 160);
        let original = fs::read(&path).unwrap();

        assert_eq!(save_recording(&recordings, &[0.2; 320], false), None);
        assert_eq!(fs::read(&path).unwrap(), original);
        assert_eq!(fs::read_dir(&recordings).unwrap().count(), 1);
    }

    #[test]
    fn failed_audio_write_still_allows_transcript_history() {
        let dir = TempDir::new();
        let mut history = History::load(&dir.0);
        // A file where the directory should be forces a write failure on every OS.
        fs::write(history.recordings_dir(), b"not a directory").unwrap();
        let audio_path = save_recording(history.recordings_dir(), &[0.1; 160], true);
        assert_eq!(audio_path, None);
        history.add("keep this text", 0.01, "Tiny", audio_path).unwrap();
        let reloaded = History::load(&dir.0);
        assert_eq!(reloaded.items()[0].transcript, "keep this text");
        assert_eq!(reloaded.items()[0].audio_path, None);
        assert_eq!(reloaded.stats().len(), 1);
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
