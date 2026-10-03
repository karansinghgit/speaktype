//! X11 queries. Also reaches XWayland apps in a Wayland session.

use x11rb::{
    connection::Connection,
    protocol::xproto::{AtomEnum, ConnectionExt},
};

/// Window classes of common terminal emulators, lowercase.
const TERMINALS: &[&str] = &[
    "alacritty",
    "blackbox",
    "com.mitchellh.ghostty",
    "cool-retro-term",
    "foot",
    "ghostty",
    "gnome-terminal",
    "gnome-terminal-server",
    "guake",
    "kitty",
    "konsole",
    "lxterminal",
    "mate-terminal",
    "org.gnome.console",
    "org.gnome.ptyxis",
    "org.wezfurlong.wezterm",
    "qterminal",
    "st",
    "st-256color",
    "tabby",
    "terminator",
    "terminology",
    "tilix",
    "urxvt",
    "warp",
    "wezterm",
    "xfce4-terminal",
    "xterm",
    "yakuake",
];

pub fn active_window_is_terminal() -> bool {
    active_window_classes().is_some_and(|classes| {
        classes
            .iter()
            .any(|class| TERMINALS.contains(&class.to_lowercase().as_str()))
    })
}

pub fn is_session() -> bool {
    std::env::var("XDG_SESSION_TYPE").is_ok_and(|t| t.eq_ignore_ascii_case("x11"))
        || (!super::wayland::is_session() && std::env::var_os("DISPLAY").is_some())
}

/// Reads WM_CLASS ("instance\0class\0") of the window in _NET_ACTIVE_WINDOW.
fn active_window_classes() -> Option<Vec<String>> {
    let (conn, screen) = x11rb::connect(None).ok()?;
    let root = conn.setup().roots.get(screen)?.root;
    let active_atom = conn
        .intern_atom(false, b"_NET_ACTIVE_WINDOW")
        .ok()?
        .reply()
        .ok()?
        .atom;
    let window = conn
        .get_property(false, root, active_atom, AtomEnum::WINDOW, 0, 1)
        .ok()?
        .reply()
        .ok()?
        .value32()?
        .next()?;
    let class = conn
        .get_property(false, window, AtomEnum::WM_CLASS, AtomEnum::STRING, 0, 256)
        .ok()?
        .reply()
        .ok()?;
    Some(
        class
            .value
            .split(|b| *b == 0)
            .filter(|part| !part.is_empty())
            .map(|part| String::from_utf8_lossy(part).into_owned())
            .collect(),
    )
}
