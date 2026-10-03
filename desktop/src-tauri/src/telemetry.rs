use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use serde::Serialize;
use sysinfo::System;
use tauri::{AppHandle, Emitter, Manager};

use crate::{dictation::TelemetryStats, platform::desktop_environment, AppState, LockExt};

pub const DEFAULT_TELEMETRY_ENDPOINT: &str = "https://telemetry.speaktype.com/api/v1/telemetry"; //todo: add actual end point
const HTTP_TIMEOUT: Duration = Duration::from_secs(3);

#[derive(Debug, Serialize, Clone)]
pub struct TelemetryPayload {
    pub anonymous_id: String,
    pub os_name: String,
    pub os_version: String,
    pub arch: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kernel_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub distribution_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub desktop_env: Option<String>,
    pub app_version: String,
    pub model: String,
    pub stats: TelemetryStats,
}

pub fn create_payload(
    app: AppHandle,
    model: String,
    anonymous_id: String,
    stats: TelemetryStats,
) -> TelemetryPayload {
    let os_name = System::name().unwrap_or_else(|| std::env::consts::OS.to_string());
    let os_version = System::os_version().unwrap_or_else(|| "Unknown".to_string());
    let arch = std::env::consts::ARCH.to_string();
    let kernel_version = System::kernel_version();
    let dist_id = System::distribution_id();
    let distribution_id = if dist_id.is_empty() {
        None
    } else {
        Some(dist_id)
    };
    let desktop_env = desktop_environment();

    TelemetryPayload {
        anonymous_id,
        os_name,
        os_version,
        arch,
        kernel_version,
        distribution_id,
        desktop_env,
        app_version: app.package_info().version.to_string(),
        model,
        stats,
    }
}

/// Resolves the telemetry endpoint URL, checking environment variable overrides first.
pub fn telemetry_endpoint() -> String {
    std::env::var("SPEAKTYPE_TELEMETRY_ENDPOINT")
        .or_else(|_| std::env::var("SPEAKTYPE_TELEMETRY_URL"))
        .unwrap_or_else(|_| DEFAULT_TELEMETRY_ENDPOINT.to_string())
}

/// Sends telemetry payload to the specified endpoint via HTTP POST.
pub async fn send_telemetry_http(endpoint: &str, payload: &TelemetryPayload) -> Result<(), String> {
    let client = reqwest::Client::builder()
        .timeout(HTTP_TIMEOUT)
        .build()
        .map_err(|e| format!("failed to build HTTP client: {e}"))?;

    let response = client
        .post(endpoint)
        .header(
            reqwest::header::USER_AGENT,
            format!("SpeakType/{}", payload.app_version),
        )
        .json(payload)
        .send()
        .await
        .map_err(|e| format!("HTTP request failed: {e}"))?;

    if response.status().is_success() {
        Ok(())
    } else {
        Err(format!(
            "telemetry server returned HTTP status {}",
            response.status()
        ))
    }
}

/// Sends telemetry payload to the configured telemetry endpoint.
pub async fn send_telemetry(payload: &TelemetryPayload) -> Result<(), String> {
    let endpoint = telemetry_endpoint();
    send_telemetry_http(&endpoint, payload).await
}

/// Synchronously sends telemetry payload, safe to call from any sync or async context.
pub fn send_telemetry_blocking(payload: &TelemetryPayload) -> Result<(), String> {
    let payload = payload.clone();
    std::thread::spawn(move || {
        tauri::async_runtime::block_on(send_telemetry(&payload))
    })
    .join()
    .map_err(|_| "telemetry sending thread panicked".to_string())?
}

static EXITING: AtomicBool = AtomicBool::new(false);

pub fn is_exiting() -> bool {
    EXITING.load(Ordering::SeqCst)
}

/// Prompts the UI to display the telemetry payload before exiting.
pub fn prompt_exit_telemetry(app: &AppHandle) {
    let state = app.state::<AppState>();
    let settings = state.settings();
    let model = settings.selected_model;
    let anonymous_id = settings.anonymous_id;
    let stats = state.telemetry.lock_unpoisoned().clone();
    let payload = create_payload(app.clone(), model, anonymous_id, stats);
    crate::tray::open_main_window(app, None);
    let _ = app.emit("show-telemetry-payload", &payload);
}

/// Gathers telemetry, logs/emits payload, and cleanly shuts down the application.
pub fn clean_exit(app: &AppHandle) {
    if EXITING.swap(true, Ordering::SeqCst) {
        return;
    }
    let state = app.state::<AppState>();
    if !state.settings().telemetry_enabled {
        eprintln!("[telemetry] disabled by user settings");
        app.exit(0);
        return;
    }
    let settings = state.settings();
    let model = settings.selected_model;
    let anonymous_id = settings.anonymous_id;
    let stats = state.telemetry.lock_unpoisoned().clone();
    let payload = create_payload(app.clone(), model, anonymous_id, stats);
    eprintln!("Exit telemetry:");
    eprintln!("{payload:?}");

    if let Err(e) = send_telemetry_blocking(&payload) {
        eprintln!("[telemetry] HTTP send failed: {e}");
    }

    app.exit(0);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_linux_payload_serialization() {
        let stats = TelemetryStats::new();
        let payload = TelemetryPayload {
            anonymous_id: "test-anon-id-123".into(),
            os_name: "Linux".into(),
            os_version: "44".into(),
            arch: "x86_64".into(),
            kernel_version: Some("6.8.0".into()),
            distribution_id: Some("fedora".into()),
            desktop_env: Some("GNOME (Wayland)".into()),
            app_version: "2.0.0".into(),
            model: "whisper-base".into(),
            stats,
        };

        let json = serde_json::to_string(&payload).unwrap();
        assert!(json.contains("\"anonymous_id\":\"test-anon-id-123\""));
        assert!(json.contains("\"distribution_id\":\"fedora\""));
        assert!(json.contains("\"desktop_env\":\"GNOME (Wayland)\""));
        assert!(json.contains("\"arch\":\"x86_64\""));
    }

    #[test]
    fn test_macos_or_windows_payload_omits_none_fields() {
        let stats = TelemetryStats::new();
        let payload = TelemetryPayload {
            anonymous_id: "test-anon-id-456".into(),
            os_name: "macOS".into(),
            os_version: "15.1".into(),
            arch: "aarch64".into(),
            kernel_version: Some("24.1.0".into()),
            distribution_id: None,
            desktop_env: None,
            app_version: "2.0.0".into(),
            model: "whisper-base".into(),
            stats,
        };

        let json = serde_json::to_string(&payload).unwrap();
        assert!(json.contains("\"anonymous_id\":\"test-anon-id-456\""));
        assert!(!json.contains("distribution_id"));
        assert!(!json.contains("desktop_env"));
        assert!(json.contains("\"os_name\":\"macOS\""));
        assert!(json.contains("\"arch\":\"aarch64\""));
    }

    #[test]
    fn test_default_telemetry_endpoint() {
        assert_eq!(DEFAULT_TELEMETRY_ENDPOINT, "https://telemetry.speaktype.com/api/v1/telemetry");
        assert!(telemetry_endpoint().starts_with("http"));
    }
}
