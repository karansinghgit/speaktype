export const isMac = navigator.userAgent.includes("Mac");

const MAC_KEY_NAMES: Record<string, string> = {
  Super: "⌘",
  Cmd: "⌘",
  Command: "⌘",
  Ctrl: "⌃",
  Control: "⌃",
  Alt: "⌥",
  Option: "⌥",
  Shift: "⇧",
};

const KEY_NAMES: Record<string, string> = {
  Super: isMac ? "⌘" : "Win",
  ArrowUp: "↑",
  ArrowDown: "↓",
  ArrowLeft: "←",
  ArrowRight: "→",
  Escape: "Esc",
  Backquote: "`",
  Minus: "-",
  Equal: "=",
  Comma: ",",
  Period: ".",
  Slash: "/",
  Semicolon: ";",
  Quote: "'",
  BracketLeft: "[",
  BracketRight: "]",
  Backslash: "\\",
};

/** Single-modifier hotkeys, as stored in settings, and how they're shown. */
export const MODIFIER_HOTKEY_LABELS: Record<string, string> = {
  Fn: "fn",
  RightCommand: "Right ⌘",
  LeftCommand: "Left ⌘",
  RightOption: "Right ⌥",
  LeftOption: "Left ⌥",
  RightControl: "Right ⌃",
  LeftControl: "Left ⌃",
};

/** Splits "Ctrl+Shift+Space" into display labels for keycaps. */
export function hotkeyParts(hotkey: string): string[] {
  if (MODIFIER_HOTKEY_LABELS[hotkey]) return [MODIFIER_HOTKEY_LABELS[hotkey]];
  return hotkey
    .split("+")
    .filter(Boolean)
    .map((part) => (isMac && MAC_KEY_NAMES[part]) || KEY_NAMES[part] || part);
}

/** "English only", "25 languages" or "99 languages". */
export function formatLanguages(model: { englishOnly: boolean; languages: string[] | null }) {
  if (model.englishOnly) return "English only";
  return `${model.languages?.length ?? 99} languages`;
}

export function formatModelSize(mb: number) {
  return mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${mb} MB`;
}

export function formatBytes(bytes: number) {
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
  if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(0)} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

/** 75 → "1:15" */
export function formatClock(totalSeconds: number) {
  const s = Math.max(0, Math.floor(totalSeconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

/** 4500 → "1h 15m", 95 → "1m 35s", 12 → "12s" */
export function formatDuration(totalSeconds: number) {
  const s = Math.round(totalSeconds);
  if (s >= 3600) return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
  if (s >= 60) return `${Math.floor(s / 60)}m ${s % 60}s`;
  return `${s}s`;
}

export function formatNumber(n: number) {
  return n.toLocaleString();
}

export function formatTime(ms: number) {
  return new Date(ms).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

/** "Today", "Yesterday", weekday within a week, else a date. */
export function formatDay(ms: number) {
  const date = new Date(ms);
  const today = new Date();
  const startOf = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const days = Math.round((startOf(today) - startOf(date)) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return date.toLocaleDateString([], { weekday: "long" });
  return date.toLocaleDateString([], {
    month: "long",
    day: "numeric",
    year: date.getFullYear() === today.getFullYear() ? undefined : "numeric",
  });
}

/** 1 → "1 transcription", 21 → "21 transcriptions" */
export function plural(count: number, noun: string) {
  return `${formatNumber(count)} ${noun}${count === 1 ? "" : "s"}`;
}

/** "21 transcriptions, 3 dictionary words and your settings" */
export function describeImport(parts: { transcripts: number; dictionary: number; settings?: boolean }) {
  const items = [
    parts.transcripts > 0 && plural(parts.transcripts, "transcription"),
    parts.dictionary > 0 && plural(parts.dictionary, "dictionary word"),
    parts.settings && "your settings",
  ].filter((item): item is string => Boolean(item));
  if (items.length <= 1) return items[0] ?? "";
  return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}

export function countWords(text: string) {
  return text.split(/\s+/).filter(Boolean).length;
}

/** "just now", "5m ago", "3h ago", "2d ago" */
export function formatRelative(ms: number, now = Date.now()) {
  const seconds = Math.max(0, Math.floor((now - ms) / 1000));
  if (seconds < 60) return "just now";
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86_400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86_400)}d ago`;
}

export function startOfDay(ms: number) {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

/** 1234 → "1.2K" */
export function formatCompact(n: number) {
  return new Intl.NumberFormat(undefined, { notation: "compact", maximumFractionDigits: 1 }).format(n);
}

/** Speed tiers from the macOS app. */
export function speedTier(score: number) {
  if (score >= 9.5) return "Blazing";
  if (score >= 8.5) return "Very fast";
  if (score >= 7) return "Fast";
  if (score >= 5.5) return "Steady";
  return "Relaxed";
}

export function accuracyTier(score: number) {
  if (score >= 9.3) return "Flawless";
  if (score >= 8.7) return "Sharp";
  if (score >= 8) return "Reliable";
  if (score >= 7) return "Solid";
  return "Rough";
}

/** 130 → "130m", 1179 → "19.7h", 12000 → "200h". Hours once minutes get hard to read. */
export function formatMinutesSaved(minutes: number) {
  if (minutes < 1000) return `${formatNumber(minutes)}m`;
  const hours = minutes / 60;
  return `${formatNumber(hours < 100 ? Math.round(hours * 10) / 10 : Math.round(hours))}h`;
}

/** Typing speed used to estimate time saved, as in the macOS app. */
export const TYPING_WORDS_PER_MINUTE = 40;
