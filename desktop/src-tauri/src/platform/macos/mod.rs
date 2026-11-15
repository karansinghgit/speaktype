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

/// NSWindowCollectionBehavior: CanJoinAllSpaces | Stationary | IgnoresCycle | FullScreenAuxiliary.
const OVERLAY_COLLECTION_BEHAVIOR: usize = (1 << 0) | (1 << 4) | (1 << 6) | (1 << 8);

/// NSStatusWindowLevel. Above normal and floating windows, so the pill is not
/// hidden behind a full-screen app's own window layer.
const STATUS_WINDOW_LEVEL: isize = 25;

/// NSWindowStyleMaskNonactivatingPanel.
const NONACTIVATING_PANEL: usize = 1 << 7;

unsafe extern "C" {
    fn object_setClass(
        obj: *mut objc2::runtime::AnyObject,
        class: *const objc2::runtime::AnyClass,
    ) -> *const objc2::runtime::AnyClass;
}

extern "C" fn never_key(
    _this: &objc2::runtime::AnyObject,
    _sel: objc2::runtime::Sel,
) -> objc2::runtime::Bool {
    objc2::runtime::Bool::NO
}

/// An NSPanel subclass that never takes focus. Only a non-activating panel can
/// show over another app's full-screen Space.
fn pill_panel_class() -> Option<&'static objc2::runtime::AnyClass> {
    use objc2::{
        runtime::{AnyClass, ClassBuilder},
        sel,
    };
    const NAME: &std::ffi::CStr = c"SpeakTypePillPanel";
    if let Some(class) = AnyClass::get(NAME) {
        return Some(class);
    }
    let mut builder = ClassBuilder::new(NAME, AnyClass::get(c"NSPanel")?)?;
    // SAFETY: both overrides match the signature of the NSWindow methods
    // (`BOOL (id, SEL)`) they replace.
    unsafe {
        builder.add_method(
            sel!(canBecomeKeyWindow),
            never_key as extern "C" fn(_, _) -> _,
        );
        builder.add_method(
            sel!(canBecomeMainWindow),
            never_key as extern "C" fn(_, _) -> _,
        );
    }
    Some(builder.register())
}

/// Lets a window appear over other apps' full-screen Spaces. It turns the
/// window into a non-activating panel, so call it only for windows that never
/// need focus. Call it on the main thread.
pub fn float_over_fullscreen(window: &WebviewWindow) {
    use objc2::{
        msg_send,
        runtime::{AnyObject, Bool},
    };

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let ns_window = ptr.cast::<AnyObject>();
    if ns_window.is_null() {
        return;
    }
    let Some(class) = pill_panel_class() else {
        return;
    };
    // SAFETY: `ns_window` is the live NSWindow that Tauri owns for this window,
    // and we are on the main thread. The panel class is a subclass of NSPanel,
    // which adds no instance variables, so swapping the class of an existing
    // NSWindow instance is the same trick that tauri-nspanel uses. The
    // selectors take the argument types used here.
    unsafe {
        let already: Bool = msg_send![ns_window, isKindOfClass: class];
        if !already.as_bool() {
            object_setClass(ns_window, class);
        }
        let mask: usize = msg_send![ns_window, styleMask];
        let _: () = msg_send![ns_window, setStyleMask: mask | NONACTIVATING_PANEL];
        let _: () = msg_send![ns_window, setFloatingPanel: Bool::YES];
        let _: () = msg_send![ns_window, setCollectionBehavior: OVERLAY_COLLECTION_BEHAVIOR];
        let _: () = msg_send![ns_window, setLevel: STATUS_WINDOW_LEVEL];
        let _: () = msg_send![ns_window, setHidesOnDeactivate: Bool::NO];
    }
}
