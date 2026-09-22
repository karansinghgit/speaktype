import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, errorMessage, type DownloadProgress, type ModelStatus, type Settings, type Status } from "./api";
import { StartupScreen } from "@/components/StartupScreen";
import { useTauriEvent } from "./useTauriEvent";

interface AppStore {
  settings: Settings;
  status: Status;
  models: ModelStatus[];
  progress: Record<string, DownloadProgress>;
  downloadErrors: Record<string, string>;
  /** Downloads a model, or with `accelerator` its Neural Engine files; errors are kept in `downloadErrors`. */
  downloadModel: (id: string, accelerator?: boolean) => Promise<void>;
  /** Saves a partial change. Rejects with the backend's message on failure. */
  updateSettings: (patch: Partial<Settings>) => Promise<void>;
  refreshModels: () => Promise<void>;
  refreshStatus: () => Promise<void>;
}

/** How long the first load keeps retrying while the app's core starts: 20 × 150ms. */
const STARTUP_ATTEMPTS = 20;
const STARTUP_RETRY_MS = 150;

const StoreContext = createContext<AppStore | null>(null);

export function useStore() {
  const store = useContext(StoreContext);
  if (!store) throw new Error("useStore must be used inside <StoreProvider>");
  return store;
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>();
  const [status, setStatus] = useState<Status>();
  const [models, setModels] = useState<ModelStatus[]>([]);
  const [progress, setProgress] = useState<Record<string, DownloadProgress>>({});
  const [downloadErrors, setDownloadErrors] = useState<Record<string, string>>({});

  const [startupError, setStartupError] = useState<string>();

  const refreshModels = useCallback(async () => setModels(await api.listModels()), []);
  const refreshStatus = useCallback(async () => setStatus(await api.getStatus()), []);
  const refreshSettings = useCallback(async () => setSettings(await api.getSettings()), []);

  // The window can be drawing before the app's core has finished starting, and
  // then the first calls are rejected with "state not managed". Retrying for a
  // few seconds covers that, on slow machines too.
  const start = useCallback(async () => {
    setStartupError(undefined);
    for (let attempt = 1; ; attempt++) {
      try {
        const [settings, status, models] = await Promise.all([
          api.getSettings(),
          api.getStatus(),
          api.listModels(),
        ]);
        setSettings(settings);
        setStatus(status);
        setModels(models);
        return;
      } catch (error) {
        if (attempt >= STARTUP_ATTEMPTS) return setStartupError(errorMessage(error));
        await new Promise((resolve) => setTimeout(resolve, STARTUP_RETRY_MS));
      }
    }
  }, []);

  useEffect(() => {
    start();
  }, [start]);

  // Permissions can change while the app is in the background.
  useEffect(() => {
    const onFocus = () => refreshStatus();
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, [refreshStatus]);

  useTauriEvent<DownloadProgress>("model-progress", ({ payload }) =>
    setProgress((p) => ({ ...p, [payload.id]: payload })),
  );
  useTauriEvent("models-changed", () => refreshModels());
  useTauriEvent("settings-changed", () => refreshSettings());

  const updateSettings = useCallback(
    async (patch: Partial<Settings>) => {
      if (!settings) return;
      const optimistic = { ...settings, ...patch };
      setSettings(optimistic);
      try {
        setSettings(await api.saveSettings(optimistic));
        if ("hotkey" in patch) refreshStatus();
      } catch (error) {
        setSettings(settings);
        throw error;
      }
    },
    [settings, refreshStatus],
  );

  const downloadModel = useCallback(async (id: string, accelerator?: boolean) => {
    setDownloadErrors(({ [id]: _, ...rest }) => rest);
    try {
      await api.downloadModel(id, accelerator);
    } catch (error) {
      const message = errorMessage(error);
      if (!message.includes("cancelled")) setDownloadErrors((e) => ({ ...e, [id]: message }));
    } finally {
      setProgress(({ [id]: _, ...rest }) => rest);
    }
  }, []);

  const value = useMemo(
    () =>
      settings && status
        ? {
            settings,
            status,
            models,
            progress,
            downloadErrors,
            downloadModel,
            updateSettings,
            refreshModels,
            refreshStatus,
          }
        : null,
    [settings, status, models, progress, downloadErrors, downloadModel, updateSettings, refreshModels, refreshStatus],
  );

  if (!value) return <StartupScreen error={startupError} onRetry={start} />;
  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}
