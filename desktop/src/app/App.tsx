import { useEffect, useState } from "react";
import { TelemetryDialog } from "@/components/TelemetryDialog";
import { UpdateDialog } from "@/components/UpdateDialog";
import { api, type TelemetryPayload, type UpdateInfo } from "@/lib/api";
import { useStore } from "@/lib/store";
import { useTauriEvent } from "@/lib/useTauriEvent";
import { NAV } from "./routes";
import { useApplyTheme } from "@/lib/theme";
import { DashboardScreen } from "@/screens/dashboard/DashboardScreen";
import { DictionaryScreen } from "@/screens/dictionary/DictionaryScreen";
import { HistoryScreen } from "@/screens/history/HistoryScreen";
import { ModelsScreen } from "@/screens/models/ModelsScreen";
import { OnboardingScreen } from "@/screens/onboarding/OnboardingScreen";
import { SettingsScreen } from "@/screens/settings/SettingsScreen";
import { StatisticsScreen } from "@/screens/statistics/StatisticsScreen";
import type { Route } from "./routes";
import { Sidebar } from "./Sidebar";

const DAY_MS = 86_400_000;
const LAST_CHECK_KEY = "lastUpdateCheck";

/** Checks GitHub for a newer release at most once a day. */
function useDailyUpdateCheck(enabled: boolean) {
  const [info, setInfo] = useState<UpdateInfo | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let last = 0;
    try {
      last = Number(localStorage.getItem(LAST_CHECK_KEY)) || 0;
    } catch {}
    if (Date.now() - last < DAY_MS) return;
    api
      .checkForUpdate()
      .then((result) => {
        try {
          localStorage.setItem(LAST_CHECK_KEY, String(Date.now()));
        } catch {}
        if (result.available) setInfo(result);
      })
      .catch(() => {});
  }, [enabled]);
  return { info, dismiss: () => setInfo(null) };
}

export function App() {
  const { settings, models, updateSettings } = useStore();
  const [route, setRoute] = useState<Route>("dashboard");
  const [telemetryPayload, setTelemetryPayload] = useState<TelemetryPayload | null>(null);

  // The menu bar panel can open a specific screen.
  useTauriEvent<string>("navigate", ({ payload }) => {
    if (NAV.some((item) => item.route === payload)) setRoute(payload as Route);
  });
  useTauriEvent<TelemetryPayload>("show-telemetry-payload", ({ payload }) => {
    setTelemetryPayload(payload);
  });
  useApplyTheme(settings.theme);

  // First launch without a model: start on AI Models, once.
  useEffect(() => {
    if (!settings.hasShownModelPrompt && !models.some((m) => m.downloaded) && models.length > 0) {
      setRoute("models");
      updateSettings({ hasShownModelPrompt: true });
    }
  }, [settings.hasShownModelPrompt, models, updateSettings]);

  const update = useDailyUpdateCheck(settings.autoUpdate && settings.hasCompletedOnboarding);

  if (!settings.hasCompletedOnboarding) {
    return <OnboardingScreen />;
  }

  return (
    <div className="flex h-full">
      <UpdateDialog update={update.info} onClose={update.dismiss} />
      <TelemetryDialog
        payload={telemetryPayload}
        isExit
        onClose={() => setTelemetryPayload(null)}
      />
      <Sidebar route={route} onNavigate={setRoute} />
      <main key={route} className="h-full min-w-0 flex-1 animate-fade-in bg-app">
        {route === "dashboard" && <DashboardScreen onNavigate={setRoute} />}
        {route === "history" && <HistoryScreen />}
        {route === "dictionary" && <DictionaryScreen />}
        {route === "statistics" && <StatisticsScreen />}
        {route === "models" && <ModelsScreen />}
        {route === "settings" && <SettingsScreen />}
      </main>
    </div>
  );
}
