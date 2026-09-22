//! The menu bar (macOS) or system tray (Windows, Linux) icon and its panel.
//!
//! Left-clicking the icon opens a small panel window under it (above it when the
//! taskbar is at the bottom). Right-clicking shows a short native menu. Linux
//! trays don't report clicks, so there the menu is the only option.

use std::{
    sync::Mutex,
    time::{Duration, Instant},
};

use tauri::{
    AppHandle, Emitter, Manager, PhysicalPosition, Rect, WebviewWindow,
    image::Image,
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
};

use crate::{
    AppState, LockExt,
    dictation::{DictationState, Event},
};

pub const TRAY_ID: &str = "main";
pub const PANEL_LABEL: &str = "tray";

/// Gap between the icon and the panel, in logical pixels.
const PANEL_GAP: f64 = 6.0;

/// When the panel last hid itself because it lost focus. Clicking the icon
/// while the panel is open blurs it first; without this the same click would
/// immediately reopen it.
static LAST_BLUR_HIDE: Mutex<Option<Instant>> = Mutex::new(None);
/// Clicks on the icon this soon after the panel hid itself are that same click.
const REOPEN_DELAY: Duration = Duration::from_millis(300);

// Template images: macOS tints them to match the menu bar.
const ICON_IDLE: &[u8] = include_bytes!("../icons/tray/idle.png");
const ICON_RECORDING: &[u8] = include_bytes!("../icons/tray/recording.png");
const ICON_BUSY: &[u8] = include_bytes!("../icons/tray/busy.png");

pub fn build(app: &AppHandle, visible: bool) -> tauri::Result<()> {
    let open = MenuItem::with_id(app, "open", "Open SpeakType", true, None::<&str>)?;
    let dictate = MenuItem::with_id(app, "dictate", "Start Dictation", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "Settings…", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit SpeakType", true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;
    let menu = Menu::with_items(
        app,
        &[&dictate, &separator, &open, &settings, &separator, &quit],
    )?;

    TrayIconBuilder::with_id(TRAY_ID)
        .tooltip("SpeakType")
        .icon(Image::from_bytes(ICON_IDLE)?)
        .icon_as_template(true)
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open" => open_main_window(app, None),
            "settings" => open_main_window(app, Some("settings")),
            "dictate" => app.state::<AppState>().controller.send(Event::Toggle),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                rect,
                ..
            } = event
            {
                toggle_panel(tray.app_handle(), rect);
            }
        })
        .build(app)?
        .set_visible(visible)?;
    Ok(())
}

/// Swaps the icon to show whether SpeakType is idle, recording or transcribing.
pub fn show_state(app: &AppHandle, state: &DictationState) {
    let Some(tray) = app.tray_by_id(TRAY_ID) else {
        return;
    };
    let bytes = match state {
        DictationState::Idle => ICON_IDLE,
        DictationState::Recording { .. } => ICON_RECORDING,
        DictationState::Transcribing => ICON_BUSY,
    };
    if let Ok(icon) = Image::from_bytes(bytes) {
        let _ = tray.set_icon_with_as_template(Some(icon), true);
    }
}

/// Shows the main window, optionally on a specific screen ("settings", "history"…).
pub fn open_main_window(app: &AppHandle, route: Option<&str>) {
    hide_panel(app);
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        // Windows ignores focus requests from a background process unless the
        // window is briefly raised above the others first.
        #[cfg(windows)]
        let _ = window.set_always_on_top(true);
        let _ = window.set_focus();
        #[cfg(windows)]
        let _ = window.set_always_on_top(false);
        if let Some(route) = route {
            let _ = app.emit_to("main", "navigate", route);
        }
    }
}

pub fn hide_panel(app: &AppHandle) {
    if let Some(panel) = app.get_webview_window(PANEL_LABEL) {
        let _ = panel.hide();
    }
}

/// Called when the panel loses focus.
pub fn panel_blurred(app: &AppHandle) {
    *LAST_BLUR_HIDE.lock_unpoisoned() = Some(Instant::now());
    hide_panel(app);
}

fn toggle_panel(app: &AppHandle, icon: Rect) {
    let Some(panel) = app.get_webview_window(PANEL_LABEL) else {
        return;
    };
    if panel.is_visible().unwrap_or(false) {
        let _ = panel.hide();
        return;
    }
    let just_hidden = LAST_BLUR_HIDE
        .lock_unpoisoned()
        .is_some_and(|hidden| hidden.elapsed() < REOPEN_DELAY);
    if just_hidden {
        return;
    }
    if let Some(position) = panel_position(app, &panel, icon) {
        let _ = panel.set_position(position);
    }
    let _ = panel.show();
    let _ = panel.set_focus();
    let _ = app.emit_to(PANEL_LABEL, "panel-shown", ());
}

/// Where the panel goes for the icon at `icon`, on the monitor that shows it.
fn panel_position(
    app: &AppHandle,
    panel: &WebviewWindow,
    icon: Rect,
) -> Option<PhysicalPosition<i32>> {
    let scale = panel.scale_factor().ok()?;
    let icon_position = icon.position.to_physical::<f64>(scale);
    let icon_size = icon.size.to_physical::<f64>(scale);
    let size = panel.outer_size().ok()?;
    let monitor = app
        .monitor_from_point(icon_position.x, icon_position.y)
        .ok()
        .flatten()
        .or_else(|| app.primary_monitor().ok().flatten())?;
    let screen = monitor.position();
    let screen_size = monitor.size();

    let (x, y) = panel_origin(
        (
            icon_position.x,
            icon_position.y,
            icon_size.width,
            icon_size.height,
        ),
        (f64::from(size.width), f64::from(size.height)),
        (
            f64::from(screen.x),
            f64::from(screen.y),
            f64::from(screen_size.width),
            f64::from(screen_size.height),
        ),
        PANEL_GAP * scale,
    );
    Some(PhysicalPosition::new(x, y))
}

/// Top-left corner of the panel, all in physical pixels with y growing
/// downwards. The panel is centred on the icon, below it when the icon is in
/// the top half of the screen (the macOS menu bar) and above it otherwise (a
/// bottom taskbar), and kept inside the screen horizontally.
fn panel_origin(
    (icon_x, icon_y, icon_w, icon_h): (f64, f64, f64, f64),
    (w, h): (f64, f64),
    (screen_x, screen_y, screen_w, screen_h): (f64, f64, f64, f64),
    gap: f64,
) -> (i32, i32) {
    let min_x = screen_x + gap;
    let max_x = (screen_x + screen_w - w - gap).max(min_x);
    let x = (icon_x + icon_w / 2.0 - w / 2.0).clamp(min_x, max_x);

    let y = if icon_y < screen_y + screen_h / 2.0 {
        icon_y + icon_h + gap
    } else {
        icon_y - h - gap
    };
    (x.round() as i32, y.round() as i32)
}

#[cfg(test)]
mod tests {
    use super::panel_origin;

    const SCREEN: (f64, f64, f64, f64) = (0.0, 0.0, 1920.0, 1080.0);
    const PANEL: (f64, f64) = (300.0, 400.0);

    #[test]
    fn opens_below_a_menu_bar_icon() {
        let icon = (1000.0, 0.0, 40.0, 24.0);
        assert_eq!(panel_origin(icon, PANEL, SCREEN, 6.0), (870, 30));
    }

    #[test]
    fn opens_above_a_taskbar_icon() {
        let icon = (1000.0, 1040.0, 40.0, 40.0);
        assert_eq!(panel_origin(icon, PANEL, SCREEN, 6.0), (870, 634));
    }

    #[test]
    fn stays_inside_the_screen_edges() {
        let right = (1900.0, 0.0, 20.0, 24.0);
        assert_eq!(panel_origin(right, PANEL, SCREEN, 6.0), (1614, 30));
        let left = (0.0, 0.0, 20.0, 24.0);
        assert_eq!(panel_origin(left, PANEL, SCREEN, 6.0), (6, 30));
    }

    #[test]
    fn uses_the_offset_of_a_secondary_monitor() {
        let screen = (-1280.0, 0.0, 1280.0, 720.0);
        let icon = (-700.0, 690.0, 30.0, 30.0);
        assert_eq!(panel_origin(icon, PANEL, screen, 6.0), (-835, 284));
    }

    #[test]
    fn a_panel_wider_than_the_screen_starts_at_its_left_edge() {
        let screen = (0.0, 0.0, 200.0, 1080.0);
        let icon = (100.0, 0.0, 20.0, 24.0);
        assert_eq!(panel_origin(icon, PANEL, screen, 6.0), (6, 30));
    }
}
