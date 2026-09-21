// Typed wrappers around the Rust commands in src-tauri/src/commands.rs.

import { invoke } from "@tauri-apps/api/core";

export type Theme = "system" | "light" | "dark";
export type RecordingMode = "hold" | "toggle";

export type PillPosition =
  | "topLeft"
  | "topCenter"
  | "topRight"
  | "centerLeft"
  | "center"
  | "centerRight"
  | "bottomLeft"
  | "bottomCenter"
  | "bottomRight";

export interface DictionaryEntry {
  id: string;
  trigger: string;
  replacement: string;
  isEnabled: boolean;
  matchWholeWord: boolean;
}

export interface Settings {
  theme: Theme;
  hotkey: string;
  recordingMode: RecordingMode;
  selectedModel: string;
  language: string;
  recentLanguages: string[];
  inputDevice: string;
  autoEdit: boolean;
  smartTrailingPunctuation: boolean;
  restoreClipboard: boolean;
  saveAudioRecordings: boolean;
  alwaysShowPill: boolean;
  pillPosition: PillPosition;
  showTrayIcon: boolean;
  autoUpdate: boolean;
  dictionary: DictionaryEntry[];
  hasCompletedOnboarding: boolean;
  hasShownModelPrompt: boolean;
}

export type OS = "macos" | "windows" | "linux";

export interface Status {
  os: OS;
  version: string;
  setupNotes: string[];
  hotkeyError: string | null;
  /** Single-modifier hotkeys this OS supports, e.g. "Fn". */
  modifierHotkeys: string[];
}

export interface InputDevice {
  id: string;
  name: string;
  isDefault: boolean;
}

export type EngineKind = "whisper" | "parakeet";

export interface ModelStatus {
  id: string;
  name: string;
  engine: EngineKind;
  sizeMb: number;
  /** Size of a fresh download here, including Neural Engine files included by default. */
  downloadMb: number;
  /** Optional Neural Engine files for Whisper on macOS. */
  acceleratorMb: number;
  accelerator: "none" | "missing" | "installed";
  englishOnly: boolean;
  /** Languages it transcribes, or null for all Whisper languages. */
  languages: string[] | null;
  description: string;
  speed: number;
  accuracy: number;
  minRamGb: number;
  downloaded: boolean;
  downloading: boolean;
}

export interface DownloadProgress {
  id: string;
  downloaded: number;
  total: number;
}

export interface EngineStatus {
  loaded: string | null;
  loading: string | null;
}

export interface DeviceReport {
  device: {
    chip: string;
    ramGb: number;
    cores: number;
    gpu: boolean;
    summary: string;
    performanceTier: number;
  };
  recommendation: { modelId: string; reason: string };
}

export interface HistoryItem {
  id: string;
  createdAt: number;
  transcript: string;
  durationSecs: number;
  model: string;
  wordCount: number;
  audioPath: string | null;
}

export interface StatsEntry {
  createdAt: number;
  wordCount: number;
  durationSecs: number;
}

export type DictationState =
  | { phase: "idle" }
  | { phase: "recording"; startedAtMs: number }
  | { phase: "transcribing" };

export type PillState =
  | { phase: "idle" }
  | { phase: "recording"; startedAtMs: number }
  | { phase: "warming" }
  | { phase: "processing"; message: string };

export type PermissionKind = "microphone" | "accessibility";

export interface Permission {
  kind: PermissionKind;
  granted: boolean;
}

/** What was brought over from SpeakType 1. */
export interface ImportSummary {
  transcripts: number;
  dictionary: number;
  settings: boolean;
}

export interface LegacyStatus {
  /** SpeakType 1's data on this computer, if there is any. */
  available: { transcripts: number; dictionary: number } | null;
  /** What was brought over at first launch. Only reported once. */
  imported: ImportSummary | null;
}

export interface UpdateInfo {
  available: boolean;
  currentVersion: string;
  latestVersion: string;
  notes: string;
  url: string;
}

export const api = {
  getStatus: () => invoke<Status>("get_status"),
  getSettings: () => invoke<Settings>("get_settings"),
  saveSettings: (settings: Settings) => invoke<Settings>("save_settings", { settings }),
  listInputDevices: () => invoke<InputDevice[]>("list_input_devices"),

  listModels: () => invoke<ModelStatus[]>("list_models"),
  getEngineStatus: () => invoke<EngineStatus>("get_engine_status"),
  getDeviceInfo: () => invoke<DeviceReport>("get_device_info"),
  downloadModel: (id: string, accelerator?: boolean) => invoke<void>("download_model", { id, accelerator }),
  cancelDownload: (id: string) => invoke<void>("cancel_download", { id }),
  deleteModel: (id: string) => invoke<void>("delete_model", { id }),

  getHistory: () => invoke<HistoryItem[]>("get_history"),
  getStats: () => invoke<StatsEntry[]>("get_stats"),
  deleteHistoryItem: (id: string) => invoke<void>("delete_history_item", { id }),
  clearHistory: () => invoke<void>("clear_history"),
  readHistoryAudio: (id: string) => invoke<ArrayBuffer>("read_history_audio", { id }),
  revealHistoryAudio: (id: string) => invoke<void>("reveal_history_audio", { id }),

  toggleDictation: () => invoke<void>("toggle_dictation"),
  getDictationState: () => invoke<DictationState>("get_dictation_state"),

  getPermissions: () => invoke<Permission[]>("get_permissions"),
  requestPermission: (kind: PermissionKind) => invoke<void>("request_permission", { kind }),
  openPermissionSettings: (kind: PermissionKind) => invoke<void>("open_permission_settings", { kind }),

  checkForUpdate: () => invoke<UpdateInfo>("check_for_update"),
  getLegacyStatus: () => invoke<LegacyStatus>("get_legacy_status"),
  importLegacy: () => invoke<ImportSummary>("import_legacy"),

  openMainWindow: (route?: string) => invoke<void>("open_main_window", { route }),
  hideTrayPanel: () => invoke<void>("hide_tray_panel"),
  quitApp: () => invoke<void>("quit_app"),
};

/** Turns a rejected invoke into a readable message. */
export function errorMessage(error: unknown) {
  return typeof error === "string" ? error : error instanceof Error ? error.message : "Something went wrong";
}
