//! Operating-system specific code. Each OS has its own folder and exposes the
//! same items, so the rest of the app never needs `cfg` checks:
//!
//! - `DEFAULT_HOTKEY`: the shortcut used until the user picks one.
//! - `MODIFIER_HOTKEYS`, `start_modifier_hotkey`, `stop_modifier_hotkey`:
//!   hotkeys made of one modifier key, where the OS allows listening for them.
//! - `send_paste_shortcut`: presses the paste keys for the focused app.
//! - `setup_notes`: OS-specific hints shown in Settings.
//! - `permissions`, `request_permission`, `permission_settings_url`: the OS
//!   permissions dictation needs, for onboarding and Settings.
//! - `style_main_window`: native window chrome tweaks.
//! - `float_over_fullscreen`: keeps a floating window visible over full screen apps.
//! - `focus_panel`: focuses the menu bar panel without disturbing the user's Space.
//! - `NEURAL_ENGINE`, `extract_zip`, `ORT_ACCELERATOR`: speech model acceleration.

use enigo::{Direction, Enigo, Key, Keyboard};
use serde::{Deserialize, Serialize};

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "linux")]
pub use linux::*;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
pub use macos::*;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
pub use windows::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PermissionKind {
    Microphone,
    Accessibility,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Permission {
    pub kind: PermissionKind,
    pub granted: bool,
}

/// A change in a single-modifier hotkey.
// Only the macOS listener sends these so far.
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HotkeyEvent {
    Down,
    Up,
    /// Another key was pressed while the hotkey was held.
    Interrupted,
}

/// Receives single-modifier hotkey changes. Called on the listener's own
/// thread, so it should return quickly.
pub type HotkeyHandler = Box<dyn Fn(HotkeyEvent) + Send + Sync>;

/// Holds the modifiers, taps `key`, then releases the modifiers even if the tap failed.
fn press_combo(enigo: &mut Enigo, modifiers: &[Key], key: Key) -> Result<(), String> {
    let mut result = Ok(());
    let mut held = Vec::new();
    for modifier in modifiers {
        match enigo.key(*modifier, Direction::Press) {
            Ok(()) => held.push(*modifier),
            Err(e) => {
                result = Err(e);
                break;
            }
        }
    }
    if result.is_ok() {
        result = enigo.key(key, Direction::Click);
    }
    for modifier in held.iter().rev() {
        let _ = enigo.key(*modifier, Direction::Release);
    }
    result.map_err(|e| format!("Couldn't simulate paste: {e}"))
}
