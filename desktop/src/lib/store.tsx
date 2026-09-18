import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, errorMessage, type DownloadProgress, type ModelStatus, type Settings, type Status } from "./api";
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
  const [initError, setInitError] = useState<string | null>(null);

  const refreshModels = useCallback(async () => {
    try {
      setModels(await api.listModels());
    } catch (err) {
      console.error("[Store] Failed to load models:", err);
    }
  }, []);

  const refreshStatus = useCallback(async () => {
    try {
      setStatus(await api.getStatus());
    } catch (err) {
      console.error("[Store] Failed to load status:", err);
    }
  }, []);

  const refreshSettings = useCallback(async () => {
    try {
      setSettings(await api.getSettings());
    } catch (err) {
      console.error("[Store] Failed to load settings:", err);
    }
  }, []);

  const initStore = useCallback(async () => {
    setInitError(null);
    const maxRetries = 10;
    const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const [loadedSettings, loadedStatus, loadedModels] = await Promise.all([
          api.getSettings(),
          api.getStatus(),
          api.listModels(),
        ]);
        setSettings(loadedSettings);
        setStatus(loadedStatus);
        setModels(loadedModels);
        setInitError(null);
        return;
      } catch (err) {
        console.warn(`[Store] Initialization attempt ${attempt}/${maxRetries} failed:`, err);
        if (attempt === maxRetries) {
          setInitError(errorMessage(err));
        } else {
          await delay(150);
        }
      }
    }
  }, []);

  const retryInit = useCallback(() => {
    initStore();
  }, [initStore]);

  useEffect(() => {
    initStore();
  }, [initStore]);

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

  if (!value) {
    if (initError) {
      return (
        <div className="flex h-screen w-screen flex-col items-center justify-center bg-app p-8 text-ink">
          <div className="flex max-w-[480px] flex-col items-center rounded-2xl border border-line bg-surface p-8 text-center shadow-lg">
            <h2 className="text-xl font-bold">Failed to initialize SpeakType</h2>
            <p className="mt-2 text-sm text-ink-secondary">
              Could not establish connection with the backend process.
            </p>
            <pre className="mt-4 max-h-32 w-full overflow-auto rounded-lg bg-surface-sunken p-3 text-left font-mono text-xs text-ink-muted">
              {initError}
            </pre>
            <button
              onClick={retryInit}
              className="mt-6 rounded-xl bg-primary px-5 py-2.5 text-sm font-medium text-on-primary transition hover:bg-primary-hover"
            >
              Retry
            </button>
          </div>
        </div>
      );
    }

    return (
      <div className="flex h-screen w-screen items-center justify-center bg-app">
        <div className="size-8 animate-spin rounded-full border-2 border-line-strong border-t-primary" />
      </div>
    );
  }

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}
