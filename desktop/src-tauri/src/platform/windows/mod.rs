//! Windows: regular global shortcuts only, and GPU acceleration chosen at
//! build time.

use std::path::Path;

use enigo::{Enigo, Key};
use tauri::WebviewWindow;

use super::{HotkeyHandler, Permission, PermissionKind};

pub const DEFAULT_HOTKEY: &str = "Ctrl+Shift+Space";

/// Ctrl+V works in regular apps, Windows Terminal and the classic console.
pub fn send_paste_shortcut(enigo: Option<&mut Enigo>) -> Result<(), String> {
    let enigo = enigo.ok_or("Keyboard simulation is unavailable")?;
    // `Key::V` is a virtual-key code, so this also works with non-Latin keyboard layouts.
    super::press_combo(enigo, &[Key::Control], Key::V)
}

pub fn setup_notes() -> Vec<String> {
    vec![
        "Windows blocks simulated keys from reaching apps that run as administrator. \
         Dictation into those apps leaves the text on the clipboard instead."
            .into(),
    ]
}

/// Windows grants microphone access per app in Settings, and a denied app gets
/// silent audio rather than an error, so there's nothing reliable to check here.
pub fn permissions() -> Vec<Permission> {
    Vec::new()
}

pub fn request_permission(_kind: PermissionKind) {}

pub fn permission_settings_url(kind: PermissionKind) -> Option<&'static str> {
    match kind {
        PermissionKind::Microphone => Some("ms-settings:privacy-microphone"),
        PermissionKind::Accessibility => None,
    }
}

pub fn style_main_window(_window: &WebviewWindow) {}

/// Nothing extra is needed here today: `alwaysOnTop` is enough for the windows
/// SpeakType shows. Exclusive full screen apps and some Wayland compositors do
/// cover floating windows, so this is where that would be handled.
pub fn float_over_fullscreen(_window: &WebviewWindow, _focusable: bool) {}

/// Showing a window here doesn't give it focus, so ask for it.
pub fn focus_panel(window: &WebviewWindow) {
    let _ = window.set_focus();
}

/// Single-modifier hotkeys aren't supported here yet.
pub const MODIFIER_HOTKEYS: &[&str] = &[];

pub fn start_modifier_hotkey(_name: &str, _handler: HotkeyHandler) -> Result<(), String> {
    Err("Single-key hotkeys aren't supported on this system yet".into())
}

pub fn stop_modifier_hotkey() {}

/// No Neural Engine; Whisper uses the GPU backend chosen at build time.
pub const NEURAL_ENGINE: bool = false;

/// Picks CUDA or another GPU provider when this build includes one, otherwise CPU.
pub const ORT_ACCELERATOR: transcribe_rs::OrtAccelerator = transcribe_rs::OrtAccelerator::Auto;

/// Only macOS downloads zipped model files.
pub fn extract_zip(_zip: &Path, _dest: &Path) -> Result<(), String> {
    Err("Zipped model files aren't used on this system".into())
}
