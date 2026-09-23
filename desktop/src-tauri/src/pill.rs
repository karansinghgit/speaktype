//! The floating recorder pill: a small transparent window that never takes focus.

use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager, PhysicalPosition};

use crate::settings::PillPosition;

pub const LABEL: &str = "pill";

/// Gap between the pill window and the screen edge, in logical pixels.
const INSET: f64 = 8.0;

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "phase", rename_all = "camelCase")]
pub enum PillState {
    Idle,
    #[serde(rename_all = "camelCase")]
    Recording {
        started_at_ms: u64,
    },
    Warming,
    Processing {
        message: String,
    },
}

/// Shows the pill in `state`, or hides it when idle unless `always_show` is on.
pub fn update(app: &AppHandle, state: PillState, position: PillPosition, always_show: bool) {
    let Some(window) = app.get_webview_window(LABEL) else {
        return;
    };
    let _ = app.emit_to(LABEL, "pill-state", &state);
    if matches!(state, PillState::Idle) && !always_show {
        let _ = window.hide();
        return;
    }
    // Only reposition when appearing, so the pill doesn't jump mid-dictation.
    if !window.is_visible().unwrap_or(false) {
        place(app, position);
        let _ = window.show();
    }
}

/// Configures whether the pill receives pointer events.
pub fn set_interactive(app: &AppHandle, interactive: bool) {
    if let Some(window) = app.get_webview_window(LABEL)
        && window.is_visible().unwrap_or(false)
    {
        let _ = window.set_ignore_cursor_events(!interactive);
    }
}

/// Moves the pill to `position` on the monitor under the mouse cursor.
pub fn place(app: &AppHandle, position: PillPosition) {
    let Some(window) = app.get_webview_window(LABEL) else {
        return;
    };
    let monitor = app
        .cursor_position()
        .ok()
        .and_then(|p| app.monitor_from_point(p.x, p.y).ok().flatten())
        .or_else(|| app.primary_monitor().ok().flatten());
    let (Some(monitor), Ok(size)) = (monitor, window.outer_size()) else {
        return;
    };
    let area = monitor.work_area();
    let inset = (INSET * monitor.scale_factor()).round() as i32;
    let (x, y) = origin(
        position,
        (
            area.position.x,
            area.position.y,
            area.size.width as i32,
            area.size.height as i32,
        ),
        (size.width as i32, size.height as i32),
        inset,
    );
    let _ = window.set_position(PhysicalPosition::new(x, y));
}

/// Top-left corner of the pill window within a work area, all in physical pixels
/// with y growing downwards. Same layout as the macOS app's `PillPosition`.
fn origin(
    position: PillPosition,
    (area_x, area_y, area_w, area_h): (i32, i32, i32, i32),
    (w, h): (i32, i32),
    inset: i32,
) -> (i32, i32) {
    use PillPosition::*;
    let left = area_x + inset;
    let center = area_x + (area_w - w) / 2;
    let right = area_x + area_w - w - inset;
    let top = area_y + inset;
    let middle = area_y + (area_h - h) / 2;
    let bottom = area_y + area_h - h - inset;
    match position {
        TopLeft => (left, top),
        TopCenter => (center, top),
        TopRight => (right, top),
        CenterLeft => (left, middle),
        Center => (center, middle),
        CenterRight => (right, middle),
        BottomLeft => (left, bottom),
        BottomCenter => (center, bottom),
        BottomRight => (right, bottom),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origins_cover_all_nine_positions() {
        // A 1920x1040 work area below a 40px top bar, and a 320x56 pill.
        let area = (0, 40, 1920, 1040);
        let size = (320, 56);
        let cases = [
            (PillPosition::TopLeft, (8, 48)),
            (PillPosition::TopCenter, (800, 48)),
            (PillPosition::TopRight, (1592, 48)),
            (PillPosition::CenterLeft, (8, 532)),
            (PillPosition::Center, (800, 532)),
            (PillPosition::CenterRight, (1592, 532)),
            (PillPosition::BottomLeft, (8, 1016)),
            (PillPosition::BottomCenter, (800, 1016)),
            (PillPosition::BottomRight, (1592, 1016)),
        ];
        for (position, expected) in cases {
            assert_eq!(origin(position, area, size, 8), expected, "{position:?}");
        }
    }

    #[test]
    fn origins_respect_a_secondary_monitor_offset() {
        let area = (-1280, 200, 1280, 720);
        assert_eq!(
            origin(PillPosition::TopLeft, area, (320, 56), 16),
            (-1264, 216)
        );
    }
}
