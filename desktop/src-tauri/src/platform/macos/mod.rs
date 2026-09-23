//! macOS: Fn and other single-modifier hotkeys through an event tap, TCC
//! permission prompts, and the Neural Engine for Whisper.

mod hotkey;
mod permissions;

use std::{path::Path, process::Command, sync::OnceLock};

use enigo::{Enigo, Key};
use objc2::{
    class,
    ffi::object_setClass,
    msg_send,
    runtime::{AnyClass, AnyObject, Bool, ClassBuilder, Sel},
    sel,
};
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

/// `NSWindowCollectionBehaviorCanJoinAllSpaces`: show on every regular Space.
const CAN_JOIN_ALL_SPACES: usize = 1 << 0;
/// `NSWindowCollectionBehaviorFullScreenAuxiliary`: also show inside another
/// app's full screen Space. Without this a window is hidden the moment any app
/// goes full screen, however high its level is.
const FULL_SCREEN_AUXILIARY: usize = 1 << 8;
/// `NSStatusWindowLevel`, the level the menu bar's own items sit at. Tauri's
/// `alwaysOnTop` only reaches `NSFloatingWindowLevel`, which macOS keeps out of
/// another app's full screen Space however its collection behavior is set.
const STATUS_WINDOW_LEVEL: isize = 25;

/// `NSWindowStyleMaskNonactivatingPanel`: the panel can take clicks and keys
/// without activating SpeakType, so showing it never pulls the user out of the
/// app, or the Space, they are in.
const NONACTIVATING_PANEL: usize = 1 << 7;

/// Gives the menu bar panel keyboard focus once it is on screen.
///
/// Nothing to do here: `show()` already sends `makeKeyAndOrderFront:`, and a
/// nonactivating panel becomes key without activating SpeakType. Activating it
/// (what Tauri's `set_focus` does) would pull the user to whichever Space the
/// main window is on and dismiss the full screen app's menu bar.
pub fn focus_panel(_window: &WebviewWindow) {}

/// Answers for the `canBecomeKeyWindow` and `canBecomeMainWindow` overrides
/// below. tao answers both from its `focusable` ivar, which belongs to the
/// window class these windows no longer have.
extern "C" fn yes(_this: &AnyObject, _cmd: Sel) -> Bool {
    Bool::YES
}

extern "C" fn no(_this: &AnyObject, _cmd: Sel) -> Bool {
    Bool::NO
}

/// The `NSPanel` subclass a window of this kind becomes, registered once.
///
/// Both kinds say no to `canBecomeMainWindow`: a panel is never the main
/// window. They differ on key status. The menu bar panel needs it, to be typed
/// into and so that losing it closes the panel. The pill must never take it:
/// it floats above whatever app someone is dictating into, so becoming key
/// would mean swallowing the keystrokes meant for that app.
///
/// Answering these here rather than leaving them to `NSPanel` is deliberate.
/// A borderless nonactivating panel happens to answer no to both on macOS 26,
/// so the pill behaves today either way, but that is an undocumented default
/// rather than anything `"focusable": false` still controls once the window's
/// class has changed.
fn panel_class(focusable: bool) -> Option<&'static AnyClass> {
    static KEY: OnceLock<Option<&'static AnyClass>> = OnceLock::new();
    static QUIET: OnceLock<Option<&'static AnyClass>> = OnceLock::new();

    let (class, name, can_become_key) = if focusable {
        (
            &KEY,
            c"SpeakTypeKeyPanel",
            yes as extern "C" fn(_, _) -> Bool,
        )
    } else {
        (
            &QUIET,
            c"SpeakTypeQuietPanel",
            no as extern "C" fn(_, _) -> Bool,
        )
    };
    *class.get_or_init(|| {
        let mut builder = ClassBuilder::new(name, class!(NSPanel))?;
        // SAFETY: both selectors take no arguments beyond the usual two and
        // return BOOL, which is what these functions do.
        unsafe {
            builder.add_method(sel!(canBecomeKeyWindow), can_become_key);
            builder.add_method(sel!(canBecomeMainWindow), no as extern "C" fn(_, _) -> Bool);
        }
        Some(builder.register())
    })
}

/// Lets a floating window (the pill, the menu bar panel) appear over full
/// screen apps, the way the Swift app's `NSPanel` did.
///
/// Three things are needed, and the window is invisible over a full screen app
/// without any one of them:
///
/// - `fullScreenAuxiliary`, which Tauri never sets: `visibleOnAllWorkspaces`
///   only gets as far as `canJoinAllSpaces`, and that covers regular Spaces.
/// - `NSStatusWindowLevel`: `alwaysOnTop` only reaches the floating level.
/// - being an `NSPanel`. A plain `NSWindow` of an inactive app is kept out of
///   another app's full screen Space whatever its flags say, so the window's
///   class is swapped for one of the `NSPanel` subclasses above.
///
/// Changing the class costs the window everything tao put on its own class:
/// `canBecomeKeyWindow` and `canBecomeMainWindow`, which tao answers from a
/// `focusable` ivar, and its `sendEvent:` override, which implements dragging
/// a window by its background. The subclasses answer the first two; the third
/// only matters for windows with drag regions, which these two don't have.
/// `tao::Window::set_focusable` would now abort, since it writes that ivar by
/// name, so nothing may call it on these windows.
///
/// Must run on the main thread, before the window is first shown.
pub fn float_over_fullscreen(window: &WebviewWindow, focusable: bool) {
    let Ok(ns_window) = window.ns_window() else {
        return;
    };
    let ns_window = ns_window.cast::<AnyObject>();
    // SAFETY: `ns_window()` returns this window's live `NSWindow`. `NSPanel` is
    // a subclass of `NSWindow` that declares no extra instance variables, so an
    // `NSWindow` can safely be made one in place. Every message below is part
    // of `NSPanel`'s public interface, and this runs on the main thread.
    unsafe {
        object_setClass(ns_window, panel_class(focusable).unwrap_or(class!(NSPanel)));

        let style: usize = msg_send![ns_window, styleMask];
        let _: () = msg_send![ns_window, setStyleMask: style | NONACTIVATING_PANEL];
        // An NSPanel hides itself when its app stops being active, which for
        // these two windows is most of the time.
        let _: () = msg_send![ns_window, setHidesOnDeactivate: false];

        let current: usize = msg_send![ns_window, collectionBehavior];
        let behavior = current | CAN_JOIN_ALL_SPACES | FULL_SCREEN_AUXILIARY;
        let _: () = msg_send![ns_window, setCollectionBehavior: behavior];
        let _: () = msg_send![ns_window, setLevel: STATUS_WINDOW_LEVEL];
    }
}
