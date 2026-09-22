//! Commands the UI calls through `invoke`.
//!
//! All are async so they run off the main thread: shortcut registration waits
//! on the main thread, and on Windows the audio APIs can't be used from it.
//! Work that can block for a while, like waiting for the engine, runs on the
//! blocking thread pool so it doesn't hold up other commands.

use std::time::Duration;

use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager, State, ipc::Response};
use tauri_plugin_opener::OpenerExt;

use crate::{
    AppState, LockExt,
    audio::{self, InputDevice},
    device::{self, DeviceInfo, Recommendation},
    dictation::{DictationState, Event},
    history::{HistoryItem, StatsEntry},
    legacy::{self, ImportSummary, V1Data},
    models::ModelStatus,
    platform::{self, Permission, PermissionKind},
    settings::Settings,
    tray,
};

type CommandResult<T> = Result<T, String>;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    os: &'static str,
    version: String,
    setup_notes: Vec<String>,
    hotkey_error: Option<String>,
    /// Single-modifier hotkeys this OS supports, e.g. "Fn".
    modifier_hotkeys: &'static [&'static str],
}

#[tauri::command]
pub async fn get_status(app: AppHandle, state: State<'_, AppState>) -> CommandResult<Status> {
    Ok(Status {
        os: std::env::consts::OS,
        version: app.package_info().version.to_string(),
        setup_notes: platform::setup_notes(),
        hotkey_error: state.hotkey_error.lock_unpoisoned().clone(),
        modifier_hotkeys: platform::MODIFIER_HOTKEYS,
    })
}

// ---- Settings ----

#[tauri::command]
pub async fn get_settings(state: State<'_, AppState>) -> CommandResult<Settings> {
    Ok(state.settings())
}

#[tauri::command]
pub async fn save_settings(
    app: AppHandle,
    state: State<'_, AppState>,
    settings: Settings,
) -> CommandResult<Settings> {
    let previous = state.settings();
    let hotkey_changed = settings.hotkey != previous.hotkey;

    if hotkey_changed {
        let registered =
            state
                .controller
                .register_hotkey(&app, &settings.hotkey, Some(&previous.hotkey));
        if let Err(e) = registered {
            // Put the old hotkey back so dictation keeps working.
            let _ = state
                .controller
                .register_hotkey(&app, &previous.hotkey, None);
            return Err(e);
        }
    }
    if let Err(e) = state.replace_settings(settings.clone()) {
        // Keep the registered hotkey in step with the saved settings.
        if hotkey_changed {
            let _ =
                state
                    .controller
                    .register_hotkey(&app, &previous.hotkey, Some(&settings.hotkey));
        }
        return Err(e);
    }
    if hotkey_changed {
        *state.hotkey_error.lock_unpoisoned() = None;
    }
    if settings.selected_model != previous.selected_model {
        state.warm_up(&app, &settings.selected_model);
    }
    if settings.show_tray_icon != previous.show_tray_icon
        && let Some(tray) = app.tray_by_id(tray::TRAY_ID)
    {
        let _ = tray.set_visible(settings.show_tray_icon);
    }
    state.controller.send(Event::RefreshPill);
    let _ = app.emit("settings-changed", ());
    Ok(settings)
}

#[tauri::command]
pub async fn list_input_devices() -> CommandResult<Vec<InputDevice>> {
    Ok(audio::list_input_devices())
}

// ---- Models ----

#[tauri::command]
pub async fn list_models(state: State<'_, AppState>) -> CommandResult<Vec<ModelStatus>> {
    Ok(state.models.statuses())
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineStatus {
    loaded: Option<String>,
    loading: Option<String>,
}

#[tauri::command]
pub async fn get_engine_status(state: State<'_, AppState>) -> CommandResult<EngineStatus> {
    let loading = state.engine_loading.lock_unpoisoned().clone();
    // While a model loads the engine is locked, and nothing is usable yet anyway.
    let loaded = state
        .engine
        .try_lock_unpoisoned()
        .and_then(|engine| engine.loaded_model().map(str::to_string));
    Ok(EngineStatus { loaded, loading })
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceReport {
    device: DeviceInfo,
    recommendation: Recommendation,
}

#[tauri::command]
pub async fn get_device_info(state: State<'_, AppState>) -> CommandResult<DeviceReport> {
    let device = state.device().clone();
    let language = state.settings().language;
    Ok(DeviceReport {
        recommendation: device::recommend(&device, &language),
        device,
    })
}

#[tauri::command]
pub async fn download_model(
    app: AppHandle,
    state: State<'_, AppState>,
    id: String,
    accelerator: Option<bool>,
) -> CommandResult<()> {
    let _ = app.emit("models-changed", ());
    let result = state
        .models
        .download(&id, accelerator, |progress| {
            let _ = app.emit("model-progress", progress);
        })
        .await;
    let _ = app.emit("models-changed", ());
    result?;

    // The first downloaded model becomes the selected one.
    let mut settings = state.settings();
    if settings.selected_model.is_empty() {
        settings.selected_model = id.clone();
        state.replace_settings(settings)?;
        let _ = app.emit("settings-changed", ());
    }
    if state.settings().selected_model == id {
        state.warm_up(&app, &id);
    }
    Ok(())
}

#[tauri::command]
pub async fn cancel_download(state: State<'_, AppState>, id: String) -> CommandResult<()> {
    state.models.cancel(&id);
    Ok(())
}

#[tauri::command]
pub async fn delete_model(
    app: AppHandle,
    state: State<'_, AppState>,
    id: String,
) -> CommandResult<()> {
    // Waits for any transcription using the model to finish.
    let unload_app = app.clone();
    let unload_id = id.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let state = unload_app.state::<AppState>();
        let mut engine = state.engine.lock_unpoisoned();
        if engine.loaded_model() == Some(unload_id.as_str()) {
            engine.unload();
        }
    })
    .await
    .map_err(|e| e.to_string())?;
    state.models.delete(&id)?;
    let mut settings = state.settings();
    if settings.selected_model == id {
        settings.selected_model.clear();
        state.replace_settings(settings)?;
        let _ = app.emit("settings-changed", ());
    }
    let _ = app.emit("models-changed", ());
    let _ = app.emit("engine-changed", ());
    Ok(())
}

// ---- History ----

#[tauri::command]
pub async fn get_history(state: State<'_, AppState>) -> CommandResult<Vec<HistoryItem>> {
    Ok(state.history.lock_unpoisoned().items().to_vec())
}

#[tauri::command]
pub async fn get_stats(state: State<'_, AppState>) -> CommandResult<Vec<StatsEntry>> {
    Ok(state.history.lock_unpoisoned().stats().to_vec())
}

#[tauri::command]
pub async fn delete_history_item(
    app: AppHandle,
    state: State<'_, AppState>,
    id: String,
) -> CommandResult<()> {
    state.history.lock_unpoisoned().delete(&id)?;
    let _ = app.emit("history-changed", ());
    Ok(())
}

#[tauri::command]
pub async fn clear_history(app: AppHandle, state: State<'_, AppState>) -> CommandResult<()> {
    state.history.lock_unpoisoned().clear()?;
    let _ = app.emit("history-changed", ());
    Ok(())
}

/// Returns the WAV bytes of an item's recording for playback.
#[tauri::command]
pub async fn read_history_audio(state: State<'_, AppState>, id: String) -> CommandResult<Response> {
    let path = state
        .history
        .lock_unpoisoned()
        .audio_path(&id)
        .ok_or("The recording for this transcript is missing")?;
    let bytes = tokio::fs::read(path).await.map_err(|e| e.to_string())?;
    Ok(Response::new(bytes))
}

#[tauri::command]
pub async fn reveal_history_audio(
    app: AppHandle,
    state: State<'_, AppState>,
    id: String,
) -> CommandResult<()> {
    let path = state
        .history
        .lock_unpoisoned()
        .audio_path(&id)
        .ok_or("The recording for this transcript is missing")?;
    app.opener()
        .reveal_item_in_dir(path)
        .map_err(|e| e.to_string())
}

// ---- Dictation ----

/// Starts or stops recording, as if the hotkey was pressed in toggle mode.
#[tauri::command]
pub async fn toggle_dictation(state: State<'_, AppState>) -> CommandResult<()> {
    state.controller.send(Event::Toggle);
    Ok(())
}

#[tauri::command]
pub async fn get_dictation_state(state: State<'_, AppState>) -> CommandResult<DictationState> {
    Ok(state.dictation_state.lock_unpoisoned().clone())
}

// ---- SpeakType 1 ----

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LegacyStatus {
    /// SpeakType 1's data on this computer, if there is any.
    available: Option<LegacyData>,
    /// What was brought over at first launch. Reported once.
    imported: Option<ImportSummary>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LegacyData {
    transcripts: usize,
    dictionary: usize,
}

fn read_legacy(app: &AppHandle) -> CommandResult<Option<V1Data>> {
    let home = app.path().home_dir().map_err(|e| e.to_string())?;
    match legacy::preferences_path(&home) {
        Some(path) => V1Data::read(&path),
        None => Ok(None),
    }
}

#[tauri::command]
pub async fn get_legacy_status(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CommandResult<LegacyStatus> {
    let available = read_legacy(&app)?
        .filter(|data| data.transcripts() > 0 || data.dictionary_len() > 0)
        .map(|data| LegacyData {
            transcripts: data.transcripts(),
            dictionary: data.dictionary_len(),
        });
    Ok(LegacyStatus {
        available,
        imported: state.legacy_import.lock_unpoisoned().take(),
    })
}

/// Adds SpeakType 1's history and dictionary entries that aren't here yet.
/// Settings are left alone, since they may have been changed here since.
#[tauri::command]
pub async fn import_legacy(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CommandResult<ImportSummary> {
    let data = read_legacy(&app)?.ok_or("There's no SpeakType 1 data on this computer")?;
    let transcripts = data.import_history(&mut state.history.lock_unpoisoned())?;
    let mut settings = state.settings();
    let dictionary = data.import_dictionary(&mut settings);
    if dictionary > 0 || !settings.has_imported_v1 {
        settings.has_imported_v1 = true;
        state.replace_settings(settings)?;
        let _ = app.emit("settings-changed", ());
    }
    if transcripts > 0 {
        let _ = app.emit("history-changed", ());
    }
    Ok(ImportSummary {
        transcripts,
        dictionary,
        settings: false,
    })
}

// ---- Permissions ----

#[tauri::command]
pub async fn get_permissions() -> CommandResult<Vec<Permission>> {
    Ok(platform::permissions())
}

#[tauri::command]
pub async fn request_permission(app: AppHandle, kind: PermissionKind) -> CommandResult<()> {
    // The macOS prompts must be shown from the main thread.
    app.run_on_main_thread(move || platform::request_permission(kind))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn open_permission_settings(app: AppHandle, kind: PermissionKind) -> CommandResult<()> {
    let url = platform::permission_settings_url(kind).ok_or("No settings page for this")?;
    app.opener()
        .open_url(url, None::<&str>)
        .map_err(|e| e.to_string())
}

// ---- Updates ----

const RELEASES_URL: &str = "https://api.github.com/repos/karansinghgit/speaktype/releases/latest";
/// Keeps a stalled connection from leaving the check pending forever.
const UPDATE_CHECK_TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateInfo {
    available: bool,
    current_version: String,
    latest_version: String,
    notes: String,
    url: String,
}

#[tauri::command]
pub async fn check_for_update(app: AppHandle) -> CommandResult<UpdateInfo> {
    #[derive(serde::Deserialize)]
    struct Release {
        tag_name: String,
        #[serde(default)]
        body: String,
        html_url: String,
    }
    let release: Release = reqwest::Client::new()
        .get(RELEASES_URL)
        .header("User-Agent", "SpeakType")
        .header("Accept", "application/vnd.github+json")
        .timeout(UPDATE_CHECK_TIMEOUT)
        .send()
        .await
        .and_then(|r| r.error_for_status())
        .map_err(|e| format!("Couldn't check for updates: {e}"))?
        .json()
        .await
        .map_err(|e| format!("Couldn't read the update info: {e}"))?;

    let current = app.package_info().version.to_string();
    let latest = release.tag_name.trim_start_matches('v').to_string();
    Ok(UpdateInfo {
        available: is_newer(&latest, &current),
        current_version: current,
        latest_version: latest,
        notes: release.body,
        url: release.html_url,
    })
}

/// Compares dotted version numbers, ignoring anything after a `-`. Missing or
/// unreadable parts count as 0.
fn is_newer(candidate: &str, current: &str) -> bool {
    let parse = |v: &str| -> Vec<u64> {
        let release = v.split_once('-').map_or(v, |(release, _)| release);
        release
            .split('.')
            .map(|part| part.parse().unwrap_or(0))
            .collect()
    };
    let (a, b) = (parse(candidate), parse(current));
    let part = |parts: &[u64], i: usize| parts.get(i).copied().unwrap_or(0);
    (0..a.len().max(b.len()))
        .map(|i| (part(&a, i), part(&b, i)))
        .find(|(x, y)| x != y)
        .is_some_and(|(x, y)| x > y)
}

#[cfg(test)]
mod tests {
    use super::is_newer;

    #[test]
    fn compares_versions_numerically() {
        assert!(is_newer("1.0.21", "1.0.9"));
        assert!(is_newer("2.0", "1.9.9"));
        assert!(!is_newer("1.0.0", "1.0"));
        assert!(!is_newer("1.0.20", "2.0.0-beta"));
    }

    #[test]
    fn equal_and_older_versions_are_not_newer() {
        assert!(!is_newer("2.0.0", "2.0.0"));
        assert!(!is_newer("1.9.9", "2.0.0"));
        assert!(!is_newer("", ""));
    }

    #[test]
    fn ignores_pre_release_suffixes() {
        assert!(!is_newer("2.0.0-alpha.5", "2.0.0"));
        assert!(is_newer("2.0.1-beta", "2.0.0"));
        assert!(is_newer("2.1", "2.0.0-alpha.5"));
    }
}

// ---- Windows ----

/// Opens the main window, optionally on a screen such as "settings" or "history".
#[tauri::command]
pub async fn open_main_window(app: AppHandle, route: Option<String>) -> CommandResult<()> {
    tray::open_main_window(&app, route.as_deref());
    Ok(())
}

#[tauri::command]
pub async fn hide_tray_panel(app: AppHandle) -> CommandResult<()> {
    tray::hide_panel(&app);
    Ok(())
}

#[tauri::command]
pub async fn quit_app(app: AppHandle) -> CommandResult<()> {
    app.exit(0);
    Ok(())
}
