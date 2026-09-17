//! Hotkeys made of a single modifier key (Fn, Right ⌘…), which the regular
//! global shortcut API can't express. A session event tap watches modifier
//! changes on its own thread, ported from the Swift app's AppDelegate.
//!
//! The tap callback runs on every key press in the session, so it only does
//! cheap work: it copies the handler out of a briefly held lock and calls it
//! after releasing it, and it never unwinds into CoreGraphics.

use std::{
    ffi::c_void,
    panic::{self, AssertUnwindSafe},
    ptr,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, AtomicPtr, Ordering},
    },
    thread,
    time::Duration,
};

use core_foundation::{
    base::{CFType, TCFType},
    mach_port::{CFMachPort, CFMachPortInvalidate, CFMachPortRef},
    number::CFNumber,
    propertylist::CFPropertyListRef,
    runloop::{CFRunLoop, kCFRunLoopCommonModes},
    string::{CFString, CFStringRef},
};
use objc2::{class, msg_send, rc::Retained, runtime::AnyObject};
use objc2_foundation::NSString;

use crate::{
    LockExt,
    platform::{HotkeyEvent, HotkeyHandler},
};

pub const MODIFIER_HOTKEYS: &[&str] = &[
    "Fn",
    "RightCommand",
    "LeftCommand",
    "RightOption",
    "LeftOption",
    "RightControl",
    "LeftControl",
];

struct Active {
    key: ModifierKey,
    handler: Arc<dyn Fn(HotkeyEvent) + Send + Sync>,
    pressed: bool,
}

static ACTIVE: Mutex<Option<Active>> = Mutex::new(None);
/// The tap's port, so the callback can switch it back on. Only the tap thread
/// reads or writes it.
static TAP: AtomicPtr<c_void> = AtomicPtr::new(ptr::null_mut());
static TAP_STARTED: AtomicBool = AtomicBool::new(false);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ModifierKey {
    Fn,
    RightCommand,
    LeftCommand,
    RightOption,
    LeftOption,
    RightControl,
    LeftControl,
}

impl ModifierKey {
    fn parse(name: &str) -> Option<Self> {
        Some(match name {
            "Fn" => Self::Fn,
            "RightCommand" => Self::RightCommand,
            "LeftCommand" => Self::LeftCommand,
            "RightOption" => Self::RightOption,
            "LeftOption" => Self::LeftOption,
            "RightControl" => Self::RightControl,
            "LeftControl" => Self::LeftControl,
            _ => return None,
        })
    }

    /// macOS virtual keycodes (`kVK_*`).
    fn keycode(self) -> i64 {
        match self {
            Self::Fn => 63,
            Self::RightCommand => 54,
            Self::LeftCommand => 55,
            Self::RightOption => 61,
            Self::LeftOption => 58,
            Self::RightControl => 62,
            Self::LeftControl => 59,
        }
    }

    /// Device-specific flag bits (`NX_DEVICE*KEYMASK`), so Right ⌘ isn't
    /// confused with Left ⌘.
    fn is_down(self, flags: u64) -> bool {
        let mask = match self {
            Self::Fn => 0x0080_0000, // kCGEventFlagMaskSecondaryFn
            Self::RightCommand => 0x10,
            Self::LeftCommand => 0x08,
            Self::RightOption => 0x40,
            Self::LeftOption => 0x20,
            Self::RightControl => 0x2000,
            Self::LeftControl => 0x01,
        };
        flags & mask != 0
    }
}

/// Starts listening for `name`, replacing any previous modifier hotkey.
pub fn start(name: &str, handler: HotkeyHandler) -> Result<(), String> {
    let key = ModifierKey::parse(name).ok_or_else(|| format!("{name} isn't a modifier key"))?;
    *ACTIVE.lock_unpoisoned() = Some(Active {
        key,
        handler: Arc::from(handler),
        pressed: false,
    });
    if !TAP_STARTED.swap(true, Ordering::SeqCst) {
        let spawned = thread::Builder::new()
            .name("modifier-hotkey".into())
            .spawn(run_tap);
        if let Err(e) = spawned {
            TAP_STARTED.store(false, Ordering::SeqCst);
            return Err(format!("Couldn't start listening for {name}: {e}"));
        }
    }
    Ok(())
}

pub fn stop() {
    *ACTIVE.lock_unpoisoned() = None;
}

type CGEventRef = *mut c_void;
type CGEventTapProxy = *mut c_void;
type CGEventTapCallBack = unsafe extern "C" fn(
    proxy: CGEventTapProxy,
    event_type: u32,
    event: CGEventRef,
    user_info: *mut c_void,
) -> CGEventRef;

// Signatures from CoreGraphics' CGEvent.h. The C enums (CGEventTapLocation,
// CGEventType, CGEventField…) are all uint32_t, CGEventMask and CGEventFlags
// are uint64_t, and CGKeyCode is uint16_t.
#[link(name = "ApplicationServices", kind = "framework")]
unsafe extern "C" {
    fn CGEventTapCreate(
        tap: u32,
        place: u32,
        options: u32,
        events_of_interest: u64,
        callback: CGEventTapCallBack,
        user_info: *mut c_void,
    ) -> CFMachPortRef;
    fn CGEventTapEnable(tap: CFMachPortRef, enable: bool);
    fn CGEventGetIntegerValueField(event: CGEventRef, field: u32) -> i64;
    fn CGEventGetFlags(event: CGEventRef) -> u64;
    fn CGEventCreateKeyboardEvent(source: *mut c_void, keycode: u16, key_down: bool) -> CGEventRef;
    fn CGEventPost(tap: u32, event: CGEventRef);
}

#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    fn CFPreferencesCopyAppValue(
        key: CFStringRef,
        application_id: CFStringRef,
    ) -> CFPropertyListRef;
    fn CFRelease(value: *const c_void);
}

const SESSION_EVENT_TAP: u32 = 1;
const HID_EVENT_TAP: u32 = 0;
const HEAD_INSERT: u32 = 0;
const TAP_OPTION_DEFAULT: u32 = 0;
const KEY_DOWN: u32 = 10;
const FLAGS_CHANGED: u32 = 12;
const TAP_DISABLED_BY_TIMEOUT: u32 = 0xFFFF_FFFE;
const TAP_DISABLED_BY_USER_INPUT: u32 = 0xFFFF_FFFF;
const KEYCODE_FIELD: u32 = 9;
/// F19, posted to break the Globe key's "show emoji picker" gesture.
const KEYCODE_F19: u16 = 0x50;
/// How often to retry creating the tap while Accessibility permission is missing.
const RETRY_INTERVAL: Duration = Duration::from_secs(2);

/// Creates the tap and runs its run loop. Without Accessibility permission
/// creation fails, so it retries until the user grants it, and it starts over
/// if the tap's port is ever invalidated.
fn run_tap() {
    let mut reported_failure = false;
    loop {
        let mask = (1u64 << FLAGS_CHANGED) | (1u64 << KEY_DOWN);
        // SAFETY: the arguments are valid CGEventTapLocation, placement and
        // option values, and `on_event` has the CGEventTapCallBack signature.
        let port = unsafe {
            CGEventTapCreate(
                SESSION_EVENT_TAP,
                HEAD_INSERT,
                TAP_OPTION_DEFAULT,
                mask,
                on_event,
                ptr::null_mut(),
            )
        };
        if !port.is_null() {
            if reported_failure {
                eprintln!("[hotkey] Accessibility granted, listening again");
                reported_failure = false;
            }
            // SAFETY: CGEventTapCreate follows the Create rule, so the port is
            // ours to release, which the wrapper does when dropped.
            let port = unsafe { CFMachPort::wrap_under_create_rule(port) };
            run_until_invalidated(&port);
        } else if !reported_failure {
            // Said once, not every retry. macOS caches the answer per process,
            // so granting Accessibility while the app runs usually needs a
            // restart before this clears.
            eprintln!(
                "[hotkey] couldn't create the event tap: Accessibility permission is missing. \
                 Grant it, then restart SpeakType."
            );
            reported_failure = true;
        }
        thread::sleep(RETRY_INTERVAL);
    }
}

fn run_until_invalidated(port: &CFMachPort) {
    let Ok(source) = port.create_runloop_source(0) else {
        return;
    };
    TAP.store(port.as_concrete_TypeRef().cast(), Ordering::Relaxed);
    let run_loop = CFRunLoop::get_current();
    // SAFETY: kCFRunLoopCommonModes is an immutable CFString constant.
    run_loop.add_source(&source, unsafe { kCFRunLoopCommonModes });
    // SAFETY: the port is a live event tap.
    unsafe { CGEventTapEnable(port.as_concrete_TypeRef(), true) };
    // Returns only once the port is invalidated and its source removed.
    CFRunLoop::run_current();
    TAP.store(ptr::null_mut(), Ordering::Relaxed);
    // SAFETY: the port is valid; invalidating an invalid port does nothing.
    unsafe { CFMachPortInvalidate(port.as_concrete_TypeRef()) };
}

/// The tap callback.
///
/// # Safety
///
/// Only CoreGraphics calls this, with a valid event for `event_type`.
unsafe extern "C" fn on_event(
    _proxy: CGEventTapProxy,
    event_type: u32,
    event: CGEventRef,
    _user_info: *mut c_void,
) -> CGEventRef {
    // Unwinding into CoreGraphics would abort the app, so a bug here passes
    // the event through instead.
    // SAFETY: the caller passes a valid event.
    panic::catch_unwind(AssertUnwindSafe(|| unsafe {
        handle_event(event_type, event)
    }))
    .unwrap_or(event)
}

/// Reports hotkey changes and returns the event to pass on, or null to swallow it.
///
/// # Safety
///
/// `event` must be a valid event of type `event_type`.
unsafe fn handle_event(event_type: u32, event: CGEventRef) -> CGEventRef {
    // macOS switches slow taps off; switch it straight back on.
    if event_type == TAP_DISABLED_BY_TIMEOUT || event_type == TAP_DISABLED_BY_USER_INPUT {
        let port = TAP.load(Ordering::Relaxed);
        if !port.is_null() {
            // SAFETY: TAP only holds the port while its run loop is running,
            // which is the only time this callback runs.
            unsafe { CGEventTapEnable(port.cast(), true) };
        }
        return event;
    }
    if event_type != FLAGS_CHANGED && event_type != KEY_DOWN {
        return event;
    }

    // SAFETY: flags-changed and key-down events both carry a keycode.
    let keycode = unsafe { CGEventGetIntegerValueField(event, KEYCODE_FIELD) };
    let (reported, is_fn) = {
        let mut guard = ACTIVE.lock_unpoisoned();
        let Some(active) = guard.as_mut() else {
            return event;
        };
        let mut reported = None;
        let mut is_fn = false;
        match event_type {
            FLAGS_CHANGED if keycode == active.key.keycode() => {
                // SAFETY: `event` is a valid event.
                let down = active.key.is_down(unsafe { CGEventGetFlags(event) });
                if down != active.pressed {
                    active.pressed = down;
                    let hotkey_event = if down {
                        HotkeyEvent::Down
                    } else {
                        HotkeyEvent::Up
                    };
                    reported = Some((Arc::clone(&active.handler), hotkey_event));
                }
                is_fn = active.key == ModifierKey::Fn;
            }
            // Another key while the hotkey is held means it's part of a normal
            // shortcut (⌘C with ⌘ as the hotkey), not a dictation.
            KEY_DOWN if active.pressed && keycode != i64::from(KEYCODE_F19) => {
                active.pressed = false;
                reported = Some((Arc::clone(&active.handler), HotkeyEvent::Interrupted));
            }
            _ => {}
        }
        (reported, is_fn)
    };

    if let Some((handler, hotkey_event)) = reported {
        handler(hotkey_event);
        if hotkey_event == HotkeyEvent::Down && is_fn {
            let spawned = thread::Builder::new()
                .name("emoji-picker".into())
                .spawn(suppress_emoji_picker);
            if let Err(e) = spawned {
                eprintln!("[hotkey] {e}");
            }
        }
    }
    // Swallow Fn so terminals don't receive stray escape sequences.
    if is_fn { ptr::null_mut() } else { event }
}

const TERMINALS: &[&str] = &[
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "com.mitchellh.ghostty",
    "io.alacritty",
    "org.alacritty",
    "net.kovidgoyal.kitty",
    "com.github.wez.wezterm",
    "dev.warp.Warp-Stable",
    "dev.warp.Warp",
    "co.zeit.hyper",
    "org.tabby",
    "com.microsoft.VSCode",
    "com.vscodium",
    "com.todesktop.230313mzl4w4u92",
];

/// Taps F19 so holding Fn doesn't open the emoji picker, unless a terminal is
/// in front (it would print the key) or the Globe key isn't set to show emoji.
fn suppress_emoji_picker() {
    if frontmost_bundle_id().is_some_and(|id| TERMINALS.contains(&id.as_str())) {
        return;
    }
    if globe_key_usage().is_some_and(|usage| usage != 2) {
        return;
    }
    for down in [true, false] {
        // SAFETY: a null source is allowed and means the default source.
        let event = unsafe { CGEventCreateKeyboardEvent(ptr::null_mut(), KEYCODE_F19, down) };
        if !event.is_null() {
            // SAFETY: the event is valid, and CGEventCreateKeyboardEvent follows
            // the Create rule, so it is released here after posting.
            unsafe {
                CGEventPost(HID_EVENT_TAP, event);
                CFRelease(event.cast_const());
            }
        }
    }
}

fn frontmost_bundle_id() -> Option<String> {
    // This runs on a short-lived thread with no autorelease pool of its own.
    objc2::rc::autoreleasepool(|_| {
        // SAFETY: +[NSWorkspace sharedWorkspace] returns NSWorkspace *,
        // frontmostApplication returns a nullable NSRunningApplication *, and
        // bundleIdentifier returns a nullable NSString *. Retained handles the
        // reference counts, and nil becomes None rather than a panic.
        unsafe {
            let workspace: Option<Retained<AnyObject>> =
                msg_send![class!(NSWorkspace), sharedWorkspace];
            let app: Option<Retained<AnyObject>> = msg_send![&*workspace?, frontmostApplication];
            let id: Option<Retained<NSString>> = msg_send![&*app?, bundleIdentifier];
            id.map(|id| id.to_string())
        }
    })
}

/// `AppleFnUsageType` from the HIToolbox preferences: 2 means "Show Emoji & Symbols".
fn globe_key_usage() -> Option<i64> {
    let key = CFString::from_static_string("AppleFnUsageType");
    let domain = CFString::from_static_string("com.apple.HIToolbox");
    // SAFETY: both arguments are valid CFStrings.
    let value = unsafe {
        CFPreferencesCopyAppValue(key.as_concrete_TypeRef(), domain.as_concrete_TypeRef())
    };
    if value.is_null() {
        return None;
    }
    // SAFETY: CFPreferencesCopyAppValue follows the Create rule and the value is non-null.
    let value = unsafe { CFType::wrap_under_create_rule(value) };
    value.downcast::<CFNumber>()?.to_i64()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_listed_hotkey_parses() {
        for name in MODIFIER_HOTKEYS {
            assert!(ModifierKey::parse(name).is_some(), "{name}");
        }
        assert_eq!(ModifierKey::parse("Ctrl+Space"), None);
    }

    #[test]
    fn left_and_right_modifiers_have_separate_flags() {
        // Right ⌘ held on its own: the generic command bit plus the right-hand bit.
        let flags = 0x0010_0000 | 0x10;
        assert!(ModifierKey::RightCommand.is_down(flags));
        assert!(!ModifierKey::LeftCommand.is_down(flags));
        assert!(ModifierKey::Fn.is_down(0x0080_0000));
    }
}
