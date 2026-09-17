//! Linux has two display servers with different rules:
//!
//! - X11 lets any app grab global shortcuts and simulate keys.
//! - Wayland blocks both. We shell out to `wtype` or `ydotool` to paste, and
//!   global shortcuts only fire while an X11 (XWayland) app has focus.

mod wayland;
mod x11;

use std::path::Path;

use enigo::{Enigo, Key};
use tauri::WebviewWindow;

use super::{HotkeyHandler, Permission, PermissionKind};

pub const DEFAULT_HOTKEY: &str = "Ctrl+Shift+Space";

pub fn send_paste_shortcut(enigo: Option<&mut Enigo>) -> Result<(), String> {
    if wayland::is_session() {
        match wayland::send_paste() {
            Ok(()) => return Ok(()),
            // Fall through to X11, which still reaches XWayland apps.
            Err(e) => eprintln!("[paste] {e}"),
        }
    }
    let enigo = enigo.ok_or("Keyboard simulation is unavailable")?;
    // Terminals use Ctrl+V for input, so they paste with Ctrl+Shift+V.
    let modifiers: &[Key] = if x11::active_window_is_terminal() {
        &[Key::Control, Key::Shift]
    } else {
        &[Key::Control]
    };
    super::press_combo(enigo, modifiers, Key::Unicode('v'))
}

pub fn setup_notes() -> Vec<String> {
    if !wayland::is_session() {
        return Vec::new();
    }
    let mut notes = vec![
        "You're on Wayland. The global hotkey only works while an X11 app has focus. \
         Switching to an X11 session gives the most reliable results."
            .to_string(),
    ];
    if !wayland::has_paste_tool() {
        notes.push(
            "Install `wtype` (Sway, Hyprland, KDE) or `ydotool` (GNOME) so SpeakType can \
             paste into Wayland apps. Without one, the text is left on the clipboard."
                .to_string(),
        );
    }
    notes
}

/// Desktop Linux has no per-app microphone or input permissions outside sandboxes.
pub fn permissions() -> Vec<Permission> {
    Vec::new()
}

pub fn request_permission(_kind: PermissionKind) {}

pub fn permission_settings_url(_kind: PermissionKind) -> Option<&'static str> {
    None
}

pub fn style_main_window(_window: &WebviewWindow) {}

/// Always on top is enough here: neither system hides floating windows for
/// full screen apps the way macOS Spaces do.
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
