//! Brings settings, the dictionary and history over from SpeakType 1, the
//! macOS-only app.
//!
//! SpeakType 1 kept everything in its preferences file: settings as plain
//! values, and history, stats and the dictionary as JSON. A fresh install
//! imports all of it on first launch. Later, Settings can import history and the
//! dictionary again, which only adds what's missing and leaves settings alone.
//! Recordings stay where SpeakType 1 saved them.

use std::{
    fs, io,
    path::{Path, PathBuf},
};

use plist::{Dictionary, Value};
use serde::{Deserialize, Serialize};

use crate::{
    history::{History, HistoryItem, StatsEntry},
    settings::{PillPosition, RecordingMode, Settings, Theme},
    text::DictionaryEntry,
};

/// Seconds between the Unix epoch and 2001-01-01, where Swift's `Date` counts from.
const APPLE_EPOCH_OFFSET_SECS: f64 = 978_307_200.0;

/// SpeakType 1's preferences file, if this system could have one.
pub fn preferences_path(home: &Path) -> Option<PathBuf> {
    cfg!(target_os = "macos").then(|| home.join("Library/Preferences/com.2048labs.speaktype.plist"))
}

/// Early SpeakType 2 builds used the app ID `com.2048labs.speaktype.desktop`,
/// before taking over SpeakType 1's `com.2048labs.speaktype` so the old app can
/// update in place. Moves an early build's folder (`dir` plus `.desktop`) to
/// `dir`, unless `dir` already has something in it. Returns whether it moved.
pub fn move_early_build_folder(dir: &Path) -> io::Result<bool> {
    let Some(name) = dir.file_name().and_then(|n| n.to_str()) else {
        return Ok(false);
    };
    let old = dir.with_file_name(format!("{name}.desktop"));
    if !old.is_dir() {
        return Ok(false);
    }
    if dir.exists() {
        if fs::read_dir(dir)?.next().is_some() {
            return Ok(false);
        }
        fs::remove_dir(dir)?;
    }
    fs::rename(&old, dir)?;
    Ok(true)
}

/// What an import brought over, for the UI to report.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportSummary {
    pub transcripts: usize,
    pub dictionary: usize,
    pub settings: bool,
}

impl ImportSummary {
    pub fn is_empty(&self) -> bool {
        self.transcripts == 0 && self.dictionary == 0 && !self.settings
    }
}

/// Everything SpeakType 1 saved, converted to this app's types.
pub struct V1Data {
    values: Dictionary,
    history: Vec<HistoryItem>,
    stats: Vec<StatsEntry>,
    dictionary: Vec<DictionaryEntry>,
}

impl V1Data {
    /// Reads SpeakType 1's preferences. `None` when there's no file.
    pub fn read(path: &Path) -> Result<Option<Self>, String> {
        if !path.is_file() {
            return Ok(None);
        }
        let values = Value::from_file(path)
            .map_err(|e| format!("Couldn't read SpeakType 1's data: {e}"))?
            .into_dictionary()
            .ok_or("SpeakType 1's data isn't in the expected format")?;
        Ok(Some(Self::from_values(values)))
    }

    fn from_values(values: Dictionary) -> Self {
        let history = json_list::<V1HistoryItem>(&values, "history_items")
            .into_iter()
            .map(V1HistoryItem::convert)
            .collect::<Vec<_>>();
        let mut stats = json_list::<V1StatsEntry>(&values, "history_stats_entries")
            .into_iter()
            .map(|s| StatsEntry::new(unix_ms(s.date), s.word_count, s.duration))
            .collect::<Vec<_>>();
        // Very old versions saved no separate stats.
        if stats.is_empty() {
            stats = history.iter().map(StatsEntry::from).collect();
        }
        let mut dictionary = json_list::<V1DictionaryEntry>(&values, "dictionary_entries")
            .into_iter()
            .map(V1DictionaryEntry::convert)
            .collect::<Vec<_>>();
        if dictionary.is_empty()
            && let Some(rules) = values
                .get("customReplacementRules")
                .and_then(Value::as_string)
        {
            dictionary = legacy_rules(rules);
        }
        Self {
            values,
            history,
            stats,
            dictionary,
        }
    }

    pub fn transcripts(&self) -> usize {
        self.history.len()
    }

    pub fn dictionary_len(&self) -> usize {
        self.dictionary.len()
    }

    /// Adds transcripts and stats that aren't in `history` yet.
    pub fn import_history(&self, history: &mut History) -> Result<usize, String> {
        history.import(self.history.clone(), self.stats.clone())
    }

    /// Adds dictionary entries whose trigger isn't in `settings` yet.
    pub fn import_dictionary(&self, settings: &mut Settings) -> usize {
        let before = settings.dictionary.len();
        for entry in &self.dictionary {
            let key = entry.trigger.trim().to_lowercase();
            if !settings
                .dictionary
                .iter()
                .any(|existing| existing.trigger.trim().to_lowercase() == key)
            {
                settings.dictionary.push(entry.clone());
            }
        }
        settings.dictionary.len() - before
    }

    /// Copies SpeakType 1's preferences onto `settings`. Returns whether any applied.
    ///
    /// Onboarding isn't carried over: permissions have to be granted again, and
    /// SpeakType 1's model files don't work here, so a model has to be downloaded.
    pub fn import_settings(&self, settings: &mut Settings) -> bool {
        let before = serde_json::to_value(&*settings).ok();
        let v = &self.values;

        if let Some(theme) = string(v, "appTheme").and_then(|t| match t {
            "Light" => Some(Theme::Light),
            "Dark" => Some(Theme::Dark),
            "System" => Some(Theme::System),
            _ => None,
        }) {
            settings.theme = theme;
        }
        if let Some(hotkey) = string(v, "selectedHotkey").and_then(hotkey_name) {
            settings.hotkey = hotkey.into();
        } else if boolean(v, "useFnKey") == Some(true) {
            settings.hotkey = "Fn".into();
        }
        if let Some(mode) = v.get("recordingMode").and_then(Value::as_signed_integer) {
            settings.recording_mode = if mode == 1 {
                RecordingMode::Toggle
            } else {
                RecordingMode::Hold
            };
        }
        if let Some(model) = string(v, "selectedModelVariant").and_then(model_id) {
            settings.selected_model = model.into();
        }
        if let Some(language) = string(v, "transcriptionLanguage").filter(|l| !l.is_empty()) {
            settings.language = language.into();
        }
        if let Some(recent) = string(v, "recentTranscriptionLanguages") {
            settings.recent_languages = recent
                .split(',')
                .map(str::trim)
                .filter(|l| !l.is_empty() && *l != "auto")
                .take(5)
                .map(String::from)
                .collect();
        }
        if let Some(position) = string(v, "recorderPillPosition")
            .and_then(|p| serde_json::from_value::<PillPosition>(p.into()).ok())
        {
            settings.pill_position = position;
        }
        let flags: [(&str, &mut bool); 6] = [
            ("enableAutoEdit", &mut settings.auto_edit),
            (
                "smartTrailingPunctuation",
                &mut settings.smart_trailing_punctuation,
            ),
            (
                "restoreClipboardAfterAutoPaste",
                &mut settings.restore_clipboard,
            ),
            ("alwaysShowRecorderPill", &mut settings.always_show_pill),
            ("showMenuBarIcon", &mut settings.show_tray_icon),
            ("autoUpdate", &mut settings.auto_update),
        ];
        for (key, field) in flags {
            if let Some(value) = boolean(v, key) {
                *field = value;
            }
        }

        serde_json::to_value(&*settings).ok() != before
    }
}

/// Imports everything into a fresh install. Settings are only touched here.
pub fn import_all(
    data: &V1Data,
    settings: &mut Settings,
    history: &mut History,
) -> Result<ImportSummary, String> {
    let settings_changed = data.import_settings(settings);
    let dictionary = data.import_dictionary(settings);
    let transcripts = data.import_history(history)?;
    Ok(ImportSummary {
        transcripts,
        dictionary,
        settings: settings_changed,
    })
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct V1HistoryItem {
    id: String,
    date: f64,
    transcript: String,
    #[serde(default)]
    duration: f64,
    #[serde(rename = "audioFileURL")]
    audio_file_url: Option<String>,
    model_used: Option<String>,
}

impl V1HistoryItem {
    fn convert(self) -> HistoryItem {
        HistoryItem {
            id: self.id.to_lowercase(),
            created_at: unix_ms(self.date),
            word_count: self.transcript.split_whitespace().count(),
            transcript: self.transcript,
            duration_secs: self.duration,
            model: self.model_used.unwrap_or_else(|| "SpeakType 1".into()),
            audio_path: self
                .audio_file_url
                .as_deref()
                .and_then(file_url_path)
                .filter(|path| Path::new(path).is_file()),
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct V1StatsEntry {
    date: f64,
    #[serde(default)]
    word_count: usize,
    #[serde(default)]
    duration: f64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct V1DictionaryEntry {
    id: Option<String>,
    trigger: String,
    #[serde(default)]
    replacement: String,
    #[serde(default = "yes")]
    is_enabled: bool,
    #[serde(default = "yes")]
    match_whole_word: bool,
}

fn yes() -> bool {
    true
}

impl V1DictionaryEntry {
    fn convert(self) -> DictionaryEntry {
        DictionaryEntry {
            id: self
                .id
                .map_or_else(|| uuid::Uuid::new_v4().to_string(), |id| id.to_lowercase()),
            trigger: self.trigger,
            replacement: self.replacement,
            is_enabled: self.is_enabled,
            match_whole_word: self.match_whole_word,
        }
    }
}

/// A JSON array SpeakType 1 saved under `key`. Unreadable entries are skipped.
fn json_list<T: for<'de> Deserialize<'de>>(values: &Dictionary, key: &str) -> Vec<T> {
    let bytes = match values.get(key) {
        Some(Value::Data(bytes)) => bytes.as_slice(),
        Some(Value::String(s)) => s.as_bytes(),
        _ => return Vec::new(),
    };
    let Ok(items) = serde_json::from_slice::<Vec<serde_json::Value>>(bytes) else {
        eprintln!("[legacy] couldn't read SpeakType 1's {key}");
        return Vec::new();
    };
    items
        .into_iter()
        .filter_map(|item| serde_json::from_value(item).ok())
        .collect()
}

fn string<'a>(values: &'a Dictionary, key: &str) -> Option<&'a str> {
    values.get(key).and_then(Value::as_string)
}

/// Swift saves `@AppStorage` booleans as booleans, but older values can be 0 or 1.
fn boolean(values: &Dictionary, key: &str) -> Option<bool> {
    let value = values.get(key)?;
    value
        .as_boolean()
        .or_else(|| value.as_signed_integer().map(|n| n != 0))
}

/// Seconds since 2001-01-01 to milliseconds since 1970-01-01.
fn unix_ms(apple_secs: f64) -> u64 {
    let ms = ((apple_secs + APPLE_EPOCH_OFFSET_SECS) * 1000.0).round();
    if ms.is_finite() && ms > 0.0 {
        // Checked above: finite and positive, and any real date fits in u64.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let ms = ms as u64;
        ms
    } else {
        0
    }
}

/// SpeakType 1's hotkey names to this app's.
fn hotkey_name(v1: &str) -> Option<&'static str> {
    Some(match v1 {
        "fn" => "Fn",
        "rightCommand" => "RightCommand",
        "leftCommand" => "LeftCommand",
        "rightOption" => "RightOption",
        "leftOption" => "LeftOption",
        "rightControl" => "RightControl",
        "leftControl" => "LeftControl",
        _ => return None,
    })
}

/// SpeakType 1's model to the closest one here, if there is one.
fn model_id(variant: &str) -> Option<&'static str> {
    let v = variant.to_lowercase();
    Some(if v.contains("parakeet") && v.contains("v3") {
        "parakeet-tdt-v3"
    } else if v.contains("parakeet") && v.contains("v2") {
        "parakeet-tdt-v2"
    } else if v.contains("turbo") {
        "large-v3-turbo"
    } else if v.contains("small.en") {
        "small-en"
    } else if v.contains("base.en") {
        "base-en"
    } else if v.contains("base") {
        "base"
    } else if v.contains("tiny") {
        "tiny"
    } else {
        return None;
    })
}

/// The oldest dictionary format: one `from => to` rule per line.
fn legacy_rules(raw: &str) -> Vec<DictionaryEntry> {
    raw.lines()
        .filter_map(|line| {
            let line = line.trim();
            let (trigger, replacement) = ["=>", "->", "="]
                .iter()
                .find_map(|sep| line.split_once(sep))?;
            let trigger = trigger.trim();
            (!trigger.is_empty()).then(|| DictionaryEntry {
                id: uuid::Uuid::new_v4().to_string(),
                trigger: trigger.into(),
                replacement: replacement.trim().into(),
                is_enabled: true,
                match_whole_word: true,
            })
        })
        .collect()
}

/// `file:///Users/me/My%20Recordings/a.wav` to `/Users/me/My Recordings/a.wav`.
fn file_url_path(url: &str) -> Option<String> {
    let encoded = url.strip_prefix("file://")?;
    let bytes = encoded.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%'
            && let Some(hex) = encoded.get(i + 1..i + 3)
            && let Ok(byte) = u8::from_str_radix(hex, 16)
        {
            decoded.push(byte);
            i += 3;
        } else {
            decoded.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(decoded).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn data(values: &[(&str, Value)]) -> V1Data {
        let mut dict = Dictionary::new();
        for (key, value) in values {
            dict.insert((*key).to_string(), value.clone());
        }
        V1Data::from_values(dict)
    }

    fn json(value: serde_json::Value) -> Value {
        Value::Data(serde_json::to_vec(&value).unwrap())
    }

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
    fn converts_history_stats_and_dates() {
        let v1 = data(&[
            (
                "history_items",
                json(serde_json::json!([{
                    "id": "C5BDB67B-8011-4434-8A48-B5D258E029D3",
                    "date": 810_544_942.5,
                    "transcript": "So essentially he gave me access",
                    "duration": 61.35,
                    "audioFileURL": "file:///definitely/not/here.wav",
                    "modelUsed": "Parakeet TDT v2"
                }, { "broken": true }])),
            ),
            (
                "history_stats_entries",
                json(
                    serde_json::json!([{ "id": "x", "date": 810_544_942.5, "wordCount": 6, "duration": 61.35 }]),
                ),
            ),
        ]);
        assert_eq!(v1.transcripts(), 1, "unreadable entries are skipped");
        let item = &v1.history[0];
        assert_eq!(item.id, "c5bdb67b-8011-4434-8a48-b5d258e029d3");
        // 2026-09-08 07:22:22.5 UTC
        assert_eq!(item.created_at, 1_788_852_142_500);
        assert_eq!(item.word_count, 6);
        assert_eq!(item.model, "Parakeet TDT v2");
        assert_eq!(item.audio_path, None, "missing recordings aren't linked");
        assert_eq!(
            serde_json::to_value(&v1.stats).unwrap(),
            serde_json::json!([{ "createdAt": 1_788_852_142_500_u64, "wordCount": 6, "durationSecs": 61.35 }])
        );
    }

    #[test]
    fn stats_fall_back_to_history_and_imports_skip_duplicates() {
        let dir = TempDir::new();
        let v1 = data(&[(
            "history_items",
            json(
                serde_json::json!([{ "id": "A", "date": 1.0, "transcript": "one two", "duration": 1.0 }]),
            ),
        )]);
        assert_eq!(v1.stats.len(), 1);

        let mut history = History::load(&dir.0);
        assert_eq!(v1.import_history(&mut history).unwrap(), 1);
        assert_eq!(v1.import_history(&mut history).unwrap(), 0);
        let reloaded = History::load(&dir.0);
        assert_eq!(reloaded.items().len(), 1);
        assert_eq!(reloaded.stats().len(), 1);
        assert_eq!(reloaded.items()[0].model, "SpeakType 1");
    }

    #[test]
    fn dictionary_merges_by_trigger_and_reads_the_oldest_format() {
        let v1 = data(&[(
            "dictionary_entries",
            json(serde_json::json!([
                { "id": "E1", "trigger": "figjam", "replacement": "FigJam", "isEnabled": false, "matchWholeWord": true },
                { "trigger": "my email", "replacement": "me@example.com" }
            ])),
        )]);
        let mut settings = Settings::default();
        settings.dictionary.push(DictionaryEntry {
            id: "mine".into(),
            trigger: "FigJam ".into(),
            replacement: "Figjam".into(),
            is_enabled: true,
            match_whole_word: true,
        });
        assert_eq!(v1.import_dictionary(&mut settings), 1);
        assert_eq!(v1.import_dictionary(&mut settings), 0);
        assert_eq!(settings.dictionary[1].replacement, "me@example.com");

        let old = data(&[(
            "customReplacementRules",
            Value::String("gonna => going to\n\n -> nothing\nteh = the".into()),
        )]);
        let rules: Vec<_> = old
            .dictionary
            .iter()
            .map(|e| (e.trigger.as_str(), e.replacement.as_str()))
            .collect();
        assert_eq!(rules, [("gonna", "going to"), ("teh", "the")]);
    }

    #[test]
    fn maps_settings_and_leaves_missing_ones_alone() {
        let v1 = data(&[
            ("appTheme", Value::String("Dark".into())),
            ("selectedHotkey", Value::String("rightCommand".into())),
            ("recordingMode", Value::Integer(1.into())),
            (
                "selectedModelVariant",
                Value::String("parakeet-tdt-0.6b-v2".into()),
            ),
            (
                "recentTranscriptionLanguages",
                Value::String("de,auto,,fr".into()),
            ),
            ("recorderPillPosition", Value::String("topRight".into())),
            ("restoreClipboardAfterAutoPaste", Value::Boolean(false)),
            ("showMenuBarIcon", Value::Integer(0.into())),
        ]);
        let mut settings = Settings::default();
        assert!(v1.import_settings(&mut settings));
        assert_eq!(settings.theme, Theme::Dark);
        assert_eq!(settings.hotkey, "RightCommand");
        assert_eq!(settings.recording_mode, RecordingMode::Toggle);
        assert_eq!(settings.selected_model, "parakeet-tdt-v2");
        assert_eq!(settings.recent_languages, ["de", "fr"]);
        assert_eq!(settings.pill_position, PillPosition::TopRight);
        assert!(!settings.restore_clipboard && !settings.show_tray_icon);
        assert_eq!(
            settings.language, "auto",
            "not saved by SpeakType 1, so unchanged"
        );
        assert!(settings.auto_update && !settings.has_completed_onboarding);

        assert!(!data(&[]).import_settings(&mut Settings::default()));
    }

    #[test]
    fn moves_an_early_build_folder_once_and_never_over_data() {
        let root = TempDir::new();
        let dir = root.0.join("com.2048labs.speaktype");
        let old = root.0.join("com.2048labs.speaktype.desktop");
        assert!(!move_early_build_folder(&dir).unwrap(), "nothing to move");

        fs::create_dir_all(old.join("models")).unwrap();
        fs::write(old.join("settings.json"), "{}").unwrap();
        fs::create_dir_all(&dir).unwrap(); // created empty by something else
        assert!(move_early_build_folder(&dir).unwrap());
        assert!(dir.join("settings.json").is_file() && dir.join("models").is_dir());
        assert!(!old.exists());
        assert!(!move_early_build_folder(&dir).unwrap(), "only once");

        fs::create_dir_all(&old).unwrap();
        fs::write(old.join("settings.json"), "{\"old\":true}").unwrap();
        assert!(
            !move_early_build_folder(&dir).unwrap(),
            "existing data wins"
        );
        assert_eq!(fs::read_to_string(dir.join("settings.json")).unwrap(), "{}");
    }

    #[test]
    fn helpers() {
        assert_eq!(
            file_url_path("file:///Users/me/My%20Recordings/a%2Bb.wav").as_deref(),
            Some("/Users/me/My Recordings/a+b.wav")
        );
        assert_eq!(file_url_path("https://example.com"), None);
        assert_eq!(
            model_id("openai_whisper-large-v3-v20240930_turbo"),
            Some("large-v3-turbo")
        );
        assert_eq!(model_id("openai_whisper-base.en"), Some("base-en"));
        assert_eq!(model_id("openai_whisper-medium"), None);
        assert_eq!(hotkey_name("leftOption"), Some("LeftOption"));
        assert_eq!(unix_ms(-1e12), 0);
    }

    #[test]
    fn reads_a_real_preferences_file() {
        let dir = TempDir::new();
        let path = dir.0.join("prefs.plist");
        let mut dict = Dictionary::new();
        dict.insert("appTheme".into(), Value::String("Light".into()));
        Value::Dictionary(dict).to_file_binary(&path).unwrap();

        let v1 = V1Data::read(&path).unwrap().unwrap();
        let mut settings = Settings::default();
        assert!(v1.import_settings(&mut settings));
        assert_eq!(settings.theme, Theme::Light);
        assert!(
            V1Data::read(&dir.0.join("missing.plist"))
                .unwrap()
                .is_none()
        );
    }
}
