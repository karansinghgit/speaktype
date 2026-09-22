//! macOS: Fn and other single-modifier hotkeys through an event tap, TCC
//! permission prompts, and the Neural Engine for Whisper.

mod hotkey;
mod permissions;

use std::{path::Path, process::Command};

use enigo::{Enigo, Key};
use tauri::{TitleBarStyle, WebviewWindow};

pub use hotkey::MODIFIER_HOTKEYS;
pub use permissions::{permission_settings_url, permissions, request_permission};

use super::HotkeyHandler;

/// Fn, as in the Swift app.
pub const DEFAULT_HOTKEY: &str = "Fn";

pub fn start_modifier_hotkey(name: &str, handler: HotkeyHandler) -> Result<(), String> {
    hotkey::start(name, handler)
}

pub fn stop_modifier_hotkey() {
    hotkey::stop();
}

/// macOS virtual keycode for V (kVK_ANSI_V), the same key the Swift app sends.
const KEYCODE_V: u32 = 0x09;

pub fn send_paste_shortcut(enigo: Option<&mut Enigo>) -> Result<(), String> {
    let enigo = enigo.ok_or("Keyboard simulation is unavailable")?;
    super::press_combo(enigo, &[Key::Meta], Key::Other(KEYCODE_V))
}

/// Whisper models get a CoreML encoder so they run on the Neural Engine.
pub const NEURAL_ENGINE: bool = true;

/// Parakeet runs on the CPU. ONNX Runtime's CoreML provider can't run most of the
/// int8 model, and splitting it made transcription 3–4x slower on an M3 Pro
/// (35 s of audio: 1.2–1.4 s on CPU, 3.5–5.2 s with CoreML).
#[cfg(parakeet)]
pub const ORT_ACCELERATOR: transcribe_rs::OrtAccelerator = transcribe_rs::OrtAccelerator::CpuOnly;

/// Unzips with `ditto`, which ships with macOS and keeps bundle metadata intact.
pub fn extract_zip(zip: &Path, dest: &Path) -> Result<(), String> {
    let status = Command::new("/usr/bin/ditto")
        .args(["-x", "-k"])
        .arg(zip)
        .arg(dest)
        .status()
        .map_err(|e| format!("Couldn't run ditto: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("ditto exited with {status}"))
    }
}

/// Permissions are shown as their own screen on macOS, so there are no extra notes.
pub fn setup_notes() -> Vec<String> {
    Vec::new()
}

/// Hides the title bar and lets content run under the traffic lights, like the Swift app.
pub fn style_main_window(window: &WebviewWindow) {
    let _ = window.set_title_bar_style(TitleBarStyle::Overlay);
    let _ = window.set_title("");
}
