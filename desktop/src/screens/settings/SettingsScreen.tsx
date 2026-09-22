import {
  BookA,
  Brain,
  ClipboardCheck,
  Command,
  Cpu,
  Globe,
  Hand,
  Import,
  KeyRound,
  Keyboard,
  Mic,
  Monitor,
  Moon,
  PanelBottom,
  RefreshCw,
  RotateCcw,
  RotateCw,
  Server,
  Shield,

  Sparkles,
  Sun,
  Wand2,
  type LucideIcon,
} from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { HotkeyPicker } from "@/components/settings/HotkeyPicker";
import { PillPositionPicker } from "@/components/settings/PillPositionPicker";
import { PermissionList } from "@/components/PermissionList";
import { UpdateDialog } from "@/components/UpdateDialog";
import {
  Badge,
  Button,
  Card,
  EmptyState,
  Page,
  PageHeader,
  Section,
  SegmentedControl,
  Select,
  SettingRow,
  Switch,
  TextArea,
  TextField,
  useToast,
  type SelectOption,
} from "@/components/ui";
import { api, errorMessage, type InputDevice, type LegacyStatus, type Settings, type UpdateInfo } from "@/lib/api";
import { cn } from "@/lib/cn";
import { describeImport } from "@/lib/format";
import { DEFAULT_LLM_PROMPT, llmUrlProblem } from "@/lib/llm";
import { LANGUAGES, languageName } from "@/lib/languages";
import { useStore } from "@/lib/store";

type Tab = "general" | "audio" | "permissions";

export function SettingsScreen() {
  const { status } = useStore();
  const [tab, setTab] = useState<Tab>("general");
  const tabs: { value: Tab; label: string; icon: LucideIcon }[] = [
    { value: "general", label: "General", icon: Command },
    { value: "audio", label: "Audio", icon: Mic },
  ];
  // Only macOS has per-app permissions to manage.
  if (status.os === "macos") tabs.push({ value: "permissions", label: "Permissions", icon: Shield });

  return (
    <Page>
      <PageHeader title="Settings" />
      <SegmentedControl value={tab} options={tabs} onChange={setTab} className="mb-8 w-[360px]" />
      {tab === "general" && <GeneralTab />}
      {tab === "audio" && <AudioTab />}
      {tab === "permissions" && <PermissionsTab />}
    </Page>
  );
}

/** Saves a settings change and shows a toast if the backend rejects it. */
function useSave() {
  const { updateSettings } = useStore();
  const toast = useToast();
  return useCallback(
    (patch: Partial<Settings>) => updateSettings(patch).catch((e) => toast(errorMessage(e), "error")),
    [updateSettings, toast],
  );
}

function GeneralTab() {
  const { settings, status } = useStore();
  const save = useSave();
  const isMac = status.os === "macos";

  return (
    <>
      <Section title="Appearance">
        <SettingRow icon={Sun} tone="neutral" label="Theme" description="Follow your system, or pick a look.">
          <SegmentedControl
            value={settings.theme}
            onChange={(theme) => save({ theme })}
            options={[
              { value: "system", label: "System", icon: Monitor },
              { value: "light", label: "Light", icon: Sun },
              { value: "dark", label: "Dark", icon: Moon },
            ]}
          />
        </SettingRow>
      </Section>

      <Section title="Shortcuts">
        <SettingRow
          icon={Keyboard}
          tone="neutral"
          label="Dictation hotkey"
          description={isMac ? "Works in every app. Fn is the easiest to reach." : "Works in every app. Click to record a new one."}
        >
          <HotkeyPicker />
        </SettingRow>
        <SettingRow
          icon={Hand}
          tone="neutral"
          label="Recording mode"
          description={
            settings.recordingMode === "hold"
              ? "Hold the hotkey while you talk, and let go when you're done."
              : "Press the hotkey to start recording, and press it again to stop."
          }
        >
          <SegmentedControl
            value={settings.recordingMode}
            onChange={(recordingMode) => save({ recordingMode })}
            options={[
              { value: "hold", label: "Hold to talk" },
              { value: "toggle", label: "Toggle" },
            ]}
            className="w-[220px]"
          />
        </SettingRow>
      </Section>

      <Section title="Behavior">
        <SettingRow
          icon={Command}
          tone="neutral"
          label={isMac ? "Show menu bar icon" : "Show tray icon"}
          description="Quick access to dictation and SpeakType's window."
        >
          <Switch checked={settings.showTrayIcon} onChange={(showTrayIcon) => save({ showTrayIcon })} />
        </SettingRow>
        <SettingRow
          icon={ClipboardCheck}
          tone="neutral"
          label="Restore clipboard after pasting"
          description={
            settings.restoreClipboard
              ? "After SpeakType pastes, whatever you had copied is put back."
              : "The transcript stays on your clipboard after SpeakType pastes it."
          }
        >
          <Switch checked={settings.restoreClipboard} onChange={(restoreClipboard) => save({ restoreClipboard })} />
        </SettingRow>
        <SettingRow
          icon={PanelBottom}
          tone="neutral"
          label="Always show the recorder pill"
          description={
            settings.alwaysShowPill
              ? "The small recorder stays on screen even when you're not dictating."
              : "The recorder appears while you dictate and hides when you're done."
          }
        >
          <Switch checked={settings.alwaysShowPill} onChange={(alwaysShowPill) => save({ alwaysShowPill })} />
        </SettingRow>
        <SettingRow icon={PanelBottom} tone="neutral" label="Recorder position" description="Where the pill appears on your screen.">
          <PillPositionPicker value={settings.pillPosition} onChange={(pillPosition) => save({ pillPosition })} />
        </SettingRow>
      </Section>

      <Section title="Transcript cleanup" description="Light, offline tidying after each dictation.">
        <SettingRow
          icon={Wand2}
          tone="neutral"
          label="Remove filler words"
          description="Takes out “um”, “uh” and similar words. The meaning of what you said never changes."
        >
          <Switch checked={settings.autoEdit} onChange={(autoEdit) => save({ autoEdit })} />
        </SettingRow>
        <SettingRow
          icon={Sparkles}
          tone="neutral"
          label="Smart trailing punctuation"
          description="When you dictate just an email, link, number or single word, the final period is dropped so it pastes clean. Sentences are left alone."
        >
          <Switch
            checked={settings.smartTrailingPunctuation}
            onChange={(smartTrailingPunctuation) => save({ smartTrailingPunctuation })}
          />
        </SettingRow>
        <SettingRow
          icon={BookA}
          tone="neutral"
          label="Replacements and snippets"
          description="Word fixes and spoken snippets (say “my email”, get your address) live in Dictionary."
        />
      </Section>

      <LlmSection />
      <LanguageSection />
      <UpdatesSection />
      <ImportSection />
    </>
  );
}

/**
 * Text settings are edited locally and saved when the field loses focus, so
 * typing doesn't write the settings file on every key.
 */
function useDraft(saved: string, commit: (value: string) => void) {
  const [draft, setDraft] = useState(saved);
  useEffect(() => setDraft(saved), [saved]);
  return {
    value: draft,
    onChange: (e: { target: { value: string } }) => setDraft(e.target.value),
    onBlur: () => {
      if (draft !== saved) commit(draft);
    },
  };
}

function LlmSection() {
  const { settings } = useStore();
  const save = useSave();
  const baseUrl = useDraft(settings.llmBaseUrl, (llmBaseUrl) => save({ llmBaseUrl: llmBaseUrl.trim() }));
  const model = useDraft(settings.llmModel, (llmModel) => save({ llmModel: llmModel.trim() }));
  const apiKey = useDraft(settings.llmApiKey, (llmApiKey) => save({ llmApiKey: llmApiKey.trim() }));
  const prompt = useDraft(settings.llmPrompt, (llmPrompt) => save({ llmPrompt }));
  const urlProblem = llmUrlProblem(baseUrl.value);

  return (
    <Section
      title="AI cleanup"
      description="Optionally send each transcript to a language model to fix grammar and wording before it's pasted."
    >
      <SettingRow
        icon={Brain}
        tone="neutral"
        label="Clean up with an LLM"
        description={
          settings.llmEnabled
            ? "If the model can't be reached within 10 seconds, the original transcript is pasted."
            : "Works with Ollama on this computer, or any OpenAI-compatible service."
        }
      >
        <Switch checked={settings.llmEnabled} onChange={(llmEnabled) => save({ llmEnabled })} />
      </SettingRow>
      {settings.llmEnabled && (
        <>
          <SettingRow
            icon={Server}
            tone="neutral"
            label="Server address"
            description={
              urlProblem ? (
                <span className="text-danger">{urlProblem}</span>
              ) : (
                "Ollama runs at http://localhost:11434/v1, so your words stay on this computer."
              )
            }
          >
            <TextField {...baseUrl} aria-label="Server address" spellCheck={false} className="w-[260px]" />
          </SettingRow>
          <SettingRow
            icon={Cpu}
            tone="neutral"
            label="Model"
            description="For Ollama, install one first, e.g. “ollama pull qwen2.5:0.5b”."
          >
            <TextField {...model} aria-label="Model" spellCheck={false} className="w-[260px]" />
          </SettingRow>
          <SettingRow
            icon={KeyRound}
            tone="neutral"
            label="API key"
            description="Only for cloud services. Saved on this computer with your other settings."
          >
            <TextField
              {...apiKey}
              type="password"
              aria-label="API key"
              placeholder="Not needed for Ollama"
              autoComplete="off"
              className="w-[260px]"
            />
          </SettingRow>
          <div className="flex flex-col gap-2 px-5 py-4">
            <div className="flex items-center">
              <span className="flex-1 type-label">Instructions</span>
              <Button
                size="sm"
                variant="ghost"
                icon={RotateCcw}
                disabled={settings.llmPrompt === DEFAULT_LLM_PROMPT}
                onClick={() => save({ llmPrompt: DEFAULT_LLM_PROMPT })}
              >
                Reset
              </Button>
            </div>
            <TextArea {...prompt} aria-label="Instructions for the model" rows={4} />
          </div>
        </>
      )}
    </Section>
  );
}

function LanguageSection() {
  const { settings } = useStore();
  const save = useSave();

  const recents = settings.recentLanguages.filter((code) => code !== settings.language);
  const options: SelectOption<string>[] = [
    { value: "auto", label: "Detect automatically" },
    ...recents.map((code) => ({ value: code, label: languageName(code), detail: "Recent" })),
    ...LANGUAGES.filter(([code]) => !recents.includes(code)).map(([code, name]) => ({ value: code, label: name })),
  ];

  const choose = (language: string) => {
    const recentLanguages =
      language === "auto"
        ? settings.recentLanguages
        : [language, ...settings.recentLanguages.filter((c) => c !== language)].slice(0, 5);
    save({ language, recentLanguages });
  };

  return (
    <Section title="Spoken language">
      <SettingRow
        icon={Globe}
        tone="neutral"
        label="Language you speak"
        description="A hint for transcription. It doesn't translate, and a wrong hint can give poor results, so detection is the safest choice."
      >
        <Select
          value={settings.language}
          options={options}
          onChange={choose}
          searchable
          aria-label="Spoken language"
          className="w-[240px]"
        />
      </SettingRow>
      <div className="px-5 py-3.5 type-small text-ink-muted">
        For languages other than English, use a multilingual model. English-only models can only write English.
      </div>
    </Section>
  );
}

function UpdatesSection() {
  const { settings, status } = useStore();
  const save = useSave();
  const toast = useToast();
  const [checking, setChecking] = useState(false);
  const [update, setUpdate] = useState<UpdateInfo | null>(null);

  const check = async () => {
    setChecking(true);
    try {
      const info = await api.checkForUpdate();
      if (info.available) setUpdate(info);
      else toast(`You're up to date. SpeakType ${info.currentVersion} is the latest version.`);
    } catch (error) {
      toast(errorMessage(error), "error");
    } finally {
      setChecking(false);
    }
  };

  return (
    <Section title="Updates" description={`SpeakType ${status.version}`}>
      <SettingRow icon={RefreshCw} label="Check for updates automatically" description="Once a day, in the background.">
        <Switch checked={settings.autoUpdate} onChange={(autoUpdate) => save({ autoUpdate })} />
      </SettingRow>
      <div className="px-5 py-4">
        <Button icon={RotateCw} loading={checking} onClick={check}>
          {checking ? "Checking…" : "Check for updates"}
        </Button>
      </div>
      <UpdateDialog update={update} onClose={() => setUpdate(null)} />
    </Section>
  );
}

/** Only shown when SpeakType 1's data is on this computer. */
function ImportSection() {
  const toast = useToast();
  const [available, setAvailable] = useState<LegacyStatus["available"]>(null);
  const [importing, setImporting] = useState(false);

  useEffect(() => {
    api
      .getLegacyStatus()
      .then((status) => setAvailable(status.available))
      .catch(() => {});
  }, []);

  if (!available) return null;

  const run = async () => {
    setImporting(true);
    try {
      const result = await api.importLegacy();
      const what = describeImport(result);
      toast(what ? `Imported ${what} from SpeakType 1.` : "Everything from SpeakType 1 is already here.");
    } catch (error) {
      toast(errorMessage(error), "error");
    } finally {
      setImporting(false);
    }
  };

  return (
    <Section title="SpeakType 1">
      <SettingRow
        icon={Import}
        tone="neutral"
        label="Import from SpeakType 1"
        description={`Found ${describeImport(available)} on this computer. Anything already here is skipped.`}
      >
        <Button loading={importing} onClick={run}>
          Import
        </Button>
      </SettingRow>
    </Section>
  );
}

function AudioTab() {
  const { settings } = useStore();
  const save = useSave();
  const [devices, setDevices] = useState<InputDevice[]>();
  const [refreshing, setRefreshing] = useState(false);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    setDevices(await api.listInputDevices());
    setRefreshing(false);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const selectedExists = devices?.some((d) => d.id === settings.inputDevice);
  const rows = [
    { id: "", name: "System default", detail: devices?.find((d) => d.isDefault)?.name },
    ...(devices ?? []).map((d) => ({ id: d.id, name: d.name, detail: undefined })),
  ];

  return (
    <>
      <div className="mb-3 flex items-end px-1">
        <div className="flex-1">
          <h2 className="type-section">Microphone</h2>
          <p className="mt-0.5 type-small text-ink-secondary">SpeakType records from this input.</p>
        </div>
        <Button size="sm" variant="ghost" icon={RotateCw} loading={refreshing} onClick={refresh}>
          Refresh
        </Button>
      </div>

      {devices && devices.length === 0 ? (
        <Card>
          <EmptyState icon={Mic} title="No microphones found" description="Connect a microphone, then refresh." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2">
          {rows.map((row) => {
            const selected = row.id === settings.inputDevice || (row.id === "" && !selectedExists);
            return (
              <button
                key={row.id || "default"}
                type="button"
                onClick={() => save({ inputDevice: row.id })}
                className={cn(
                  "flex items-center gap-3.5 rounded-card border bg-surface px-4 py-3.5 text-left transition-colors",
                  selected ? "border-accent/50" : "border-line hover:border-line-strong",
                )}
              >
                <span
                  className={cn(
                    "flex size-[18px] shrink-0 items-center justify-center rounded-full border-[1.5px] transition-colors",
                    selected ? "border-accent" : "border-line-strong",
                  )}
                >
                  {selected && <span className="size-2 rounded-full bg-accent" />}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate type-label">{row.name}</span>
                  {row.detail && <span className="block truncate type-caption text-ink-muted">{row.detail}</span>}
                </span>
                {selected && (
                  <Badge tone="success" icon={Mic}>
                    In use
                  </Badge>
                )}
              </button>
            );
          })}
        </div>
      )}
    </>
  );
}

function PermissionsTab() {
  return (
    <>
      <div className="mb-3 px-1">
        <h2 className="type-section">App permissions</h2>
        <p className="mt-0.5 type-small text-ink-secondary">SpeakType needs both to dictate into other apps.</p>
      </div>
      <PermissionList />
    </>
  );
}
