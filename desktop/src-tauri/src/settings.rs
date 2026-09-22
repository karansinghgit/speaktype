//! User settings, stored as JSON in the app's config directory.
//!
//! Every field falls back to its default when missing, so settings files from
//! older versions keep loading as fields are added.

use std::{
    fs::{self, File},
    io::{self, ErrorKind, Write},
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};

use crate::text::DictionaryEntry;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RecordingMode {
    /// Record while the hotkey is held, transcribe on release.
    Hold,
    /// Press once to start, again to stop.
    Toggle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PillPosition {
    TopLeft,
    TopCenter,
    TopRight,
    CenterLeft,
    Center,
    CenterRight,
    BottomLeft,
    BottomCenter,
    BottomRight,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Theme {
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub theme: Theme,
    /// Global shortcut in Tauri accelerator syntax, e.g. "Ctrl+Shift+Space".
    pub hotkey: String,
    pub recording_mode: RecordingMode,
    /// Id from `models::CATALOG`, or empty when nothing is selected yet.
    pub selected_model: String,
    /// Whisper language code, or "auto" to detect.
    pub language: String,
    /// Most recently chosen languages, newest first, at most five, never "auto".
    pub recent_languages: Vec<String>,
    /// Input device id from cpal, or empty for the system default.
    pub input_device: String,
    pub auto_edit: bool,
    pub smart_trailing_punctuation: bool,
    pub restore_clipboard: bool,
    pub always_show_pill: bool,
    pub pill_position: PillPosition,
    pub show_tray_icon: bool,
    pub auto_update: bool,
    pub dictionary: Vec<DictionaryEntry>,
    pub has_completed_onboarding: bool,
    /// Set once SpeakType 1's data has been brought over, so it only happens once.
    pub has_imported_v1: bool,
    /// Set once the app has sent a new user to AI Models, so it only happens once.
    pub has_shown_model_prompt: bool,
    /// Send finished transcripts to an LLM to clean them up.
    pub llm_enabled: bool,
    /// Base URL of an OpenAI-compatible API, e.g. "http://localhost:11434/v1".
    pub llm_base_url: String,
    pub llm_model: String,
    /// System prompt sent with every transcript.
    pub llm_prompt: String,
    /// Sent as a bearer token when not empty. Local servers like Ollama don't need one.
    pub llm_api_key: String,
}

pub const DEFAULT_LLM_BASE_URL: &str = "http://localhost:11434/v1";
pub const DEFAULT_LLM_MODEL: &str = "qwen2.5:0.5b";
pub const DEFAULT_LLM_PROMPT: &str = "You are a post-processor for voice dictation. Fix typos, \
    remove filler words, correct grammar, and clean up the text while preserving the original \
    meaning. Output ONLY the corrected text with no explanation.";

impl Default for Settings {
    fn default() -> Self {
        Self {
            theme: Theme::System,
            hotkey: crate::platform::DEFAULT_HOTKEY.to_string(),
            recording_mode: RecordingMode::Hold,
            selected_model: String::new(),
            language: "auto".to_string(),
            recent_languages: Vec::new(),
            input_device: String::new(),
            auto_edit: false,
            smart_trailing_punctuation: true,
            restore_clipboard: true,
            always_show_pill: false,
            pill_position: PillPosition::BottomCenter,
            show_tray_icon: true,
            auto_update: true,
            dictionary: Vec::new(),
            has_completed_onboarding: false,
            has_imported_v1: false,
            has_shown_model_prompt: false,
            llm_enabled: false,
            llm_base_url: DEFAULT_LLM_BASE_URL.to_string(),
            llm_model: DEFAULT_LLM_MODEL.to_string(),
            llm_prompt: DEFAULT_LLM_PROMPT.to_string(),
            llm_api_key: String::new(),
        }
    }
}

pub struct SettingsStore {
    path: PathBuf,
}

impl SettingsStore {
    pub fn new(config_dir: PathBuf) -> Self {
        Self {
            path: config_dir.join("settings.json"),
        }
    }

    /// Whether settings have ever been saved here, i.e. this isn't a fresh install.
    pub fn exists(&self) -> bool {
        self.path.exists()
    }

    /// Reads settings, falling back to defaults if the file is missing or unreadable.
    ///
    /// An unreadable file is moved aside to `settings.json.corrupt` and logged,
    /// so the next save doesn't silently overwrite the user's settings.
    pub fn load(&self) -> Settings {
        let parsed = match fs::read(&self.path) {
            Ok(bytes) => serde_json::from_slice(&bytes).map_err(|e| e.to_string()),
            Err(e) if e.kind() == ErrorKind::NotFound => return Settings::default(),
            Err(e) => Err(e.to_string()),
        };
        parsed.unwrap_or_else(|e| {
            let backup = self.path.with_extension("json.corrupt");
            eprintln!(
                "[settings] couldn't read {}: {e}; moving it to {}",
                self.path.display(),
                backup.display()
            );
            if let Err(e) = fs::rename(&self.path, &backup) {
                eprintln!("[settings] couldn't move it aside: {e}");
            }
            Settings::default()
        })
    }

    /// Saves settings. Writes to a temporary file, flushes it to disk and renames
    /// it into place, so a crash mid-write can't leave a truncated file.
    pub fn save(&self, settings: &Settings) -> Result<(), String> {
        if let Some(dir) = self.path.parent() {
            fs::create_dir_all(dir).map_err(|e| e.to_string())?;
        }
        let json = serde_json::to_vec_pretty(settings).map_err(|e| e.to_string())?;
        let tmp = self.path.with_extension("json.tmp");
        let result = write_synced(&tmp, &json).and_then(|()| fs::rename(&tmp, &self.path));
        if result.is_err() {
            let _ = fs::remove_file(&tmp);
        }
        result.map_err(|e| e.to_string())
    }
}

fn write_synced(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let mut file = File::create(path)?;
    file.write_all(bytes)?;
    file.sync_all()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_store() -> (SettingsStore, PathBuf) {
        let dir = std::env::temp_dir().join(format!("speaktype-test-{}", uuid::Uuid::new_v4()));
        (SettingsStore::new(dir.join("config")), dir)
    }

    #[test]
    fn missing_file_loads_defaults() {
        let (store, dir) = temp_store();
        let settings = store.load();
        assert_eq!(settings.theme, Theme::System);
        assert_eq!(settings.language, "auto");
        assert_eq!(settings.pill_position, PillPosition::BottomCenter);
        assert!(settings.smart_trailing_punctuation && settings.restore_clipboard);
        assert!(!dir.exists(), "loading doesn't create anything");
    }

    #[test]
    fn llm_post_processing_is_off_and_points_at_local_ollama_by_default() {
        let settings = Settings::default();
        assert!(!settings.llm_enabled);
        assert_eq!(settings.llm_base_url, "http://localhost:11434/v1");
        assert_eq!(settings.llm_model, DEFAULT_LLM_MODEL);
        assert_eq!(settings.llm_prompt, DEFAULT_LLM_PROMPT);
        assert!(settings.llm_api_key.is_empty());
    }

    #[test]
    fn llm_settings_round_trip() {
        let (store, dir) = temp_store();
        let settings = Settings {
            llm_enabled: true,
            llm_base_url: "https://api.openai.com/v1".into(),
            llm_model: "gpt-4o-mini".into(),
            llm_prompt: "Only fix spelling.".into(),
            llm_api_key: "sk-test".into(),
            ..Settings::default()
        };
        store.save(&settings).unwrap();

        let loaded = store.load();
        assert!(loaded.llm_enabled);
        assert_eq!(loaded.llm_base_url, "https://api.openai.com/v1");
        assert_eq!(loaded.llm_model, "gpt-4o-mini");
        assert_eq!(loaded.llm_prompt, "Only fix spelling.");
        assert_eq!(loaded.llm_api_key, "sk-test");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn save_and_load_round_trip() {
        let (store, dir) = temp_store();
        let mut settings = Settings {
            recording_mode: RecordingMode::Toggle,
            selected_model: "base".into(),
            recent_languages: vec!["de".into(), "fr".into()],
            ..Settings::default()
        };
        store.save(&settings).unwrap();
        settings.theme = Theme::Dark;
        store.save(&settings).unwrap();

        let loaded = store.load();
        assert_eq!(loaded.theme, Theme::Dark);
        assert_eq!(loaded.recording_mode, RecordingMode::Toggle);
        assert_eq!(loaded.selected_model, "base");
        assert_eq!(loaded.recent_languages, ["de", "fr"]);
        assert!(!dir.join("config/settings.json.tmp").exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn older_files_missing_fields_keep_what_they_have() {
        let json = r#"{
            "theme": "light",
            "recordingMode": "toggle",
            "pillPosition": "topRight",
            "dictionary": [{"id": "1", "trigger": "speak type", "replacement": "SpeakType"}]
        }"#;
        let settings: Settings = serde_json::from_str(json).unwrap();
        assert_eq!(settings.theme, Theme::Light);
        assert_eq!(settings.recording_mode, RecordingMode::Toggle);
        assert_eq!(settings.pill_position, PillPosition::TopRight);
        assert_eq!(settings.hotkey, crate::platform::DEFAULT_HOTKEY);
        assert!(settings.show_tray_icon);
        assert!(!settings.llm_enabled);
        assert_eq!(settings.llm_base_url, DEFAULT_LLM_BASE_URL);
        assert_eq!(settings.llm_prompt, DEFAULT_LLM_PROMPT);
        let entry = &settings.dictionary[0];
        assert!(entry.is_enabled && entry.match_whole_word);
    }

    #[test]
    fn serializes_with_the_field_names_the_frontend_expects() {
        let value = serde_json::to_value(Settings::default()).unwrap();
        for key in [
            "theme",
            "hotkey",
            "recordingMode",
            "selectedModel",
            "language",
            "recentLanguages",
            "inputDevice",
            "autoEdit",
            "smartTrailingPunctuation",
            "restoreClipboard",
            "alwaysShowPill",
            "pillPosition",
            "showTrayIcon",
            "autoUpdate",
            "dictionary",
            "hasCompletedOnboarding",
            "hasShownModelPrompt",
            "llmEnabled",
            "llmBaseUrl",
            "llmModel",
            "llmPrompt",
            "llmApiKey",
        ] {
            assert!(value.get(key).is_some(), "missing {key}");
        }
        assert_eq!(value["pillPosition"], "bottomCenter");
        assert_eq!(value["recordingMode"], "hold");
    }

    #[test]
    fn unreadable_file_is_set_aside_and_defaults_load() {
        let (store, dir) = temp_store();
        fs::create_dir_all(dir.join("config")).unwrap();
        fs::write(dir.join("config/settings.json"), r#"{"theme": "sepia"}"#).unwrap();

        assert_eq!(store.load().theme, Theme::System);
        assert!(dir.join("config/settings.json.corrupt").is_file());
        assert!(!dir.join("config/settings.json").exists());
        fs::remove_dir_all(dir).unwrap();
    }
}
