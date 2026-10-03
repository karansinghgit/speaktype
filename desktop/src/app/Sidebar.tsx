import { Power } from "lucide-react";
import { LogoMark } from "@/components/brand/LogoMark";
import { api } from "@/lib/api";
import { cn } from "@/lib/cn";
import { useStore } from "@/lib/store";
import { NAV, type Route } from "./routes";

/** Black in both themes; the one place neon green sits on a large dark surface. */
export function Sidebar({ route, onNavigate }: { route: Route; onNavigate: (route: Route) => void }) {
  const { status, settings } = useStore();
  // On macOS the window's traffic lights sit over the top of the sidebar.
  const macChrome = status.os === "macos";
  const isDebug = Boolean(status.debug ?? import.meta.env.DEV);

  return (
    <nav className="flex h-full w-[232px] shrink-0 flex-col bg-sidebar text-white">
      <div data-tauri-drag-region className={cn("shrink-0", macChrome ? "h-11" : "h-4")} />

      <div data-tauri-drag-region className="flex items-center gap-2.5 px-5 pt-1 pb-7">
        <LogoMark className="pointer-events-none size-8 ring-1 ring-white/15 rounded-control" />
        <span className="pointer-events-none type-section">SpeakType</span>
      </div>

      <div className="flex flex-col gap-0.5 px-3">
        {NAV.map(({ route: r, label, icon: Icon }) => {
          const active = r === route;
          return (
            <button
              key={r}
              type="button"
              aria-current={active ? "page" : undefined}
              onClick={() => onNavigate(r)}
              className={cn(
                "group flex h-9 items-center gap-3 rounded-control px-3 text-left type-label transition-colors duration-150",
                active ? "bg-white/10 font-medium text-white" : "text-white/60 hover:bg-white/5 hover:text-white",
              )}
            >
              <Icon
                size={17}
                strokeWidth={2}
                className={cn("shrink-0 transition-colors", active ? "text-accent" : "text-white/45 group-hover:text-white/80")}
              />
              {label}
            </button>
          );
        })}
      </div>

      <div className="flex-1" />

      {isDebug && (
        <div className="flex flex-col gap-1.5 px-3 pb-2">
          <div className="flex items-center justify-between px-3 py-1 type-caption text-white/50">
            <span>Telemetry</span>
            <span
              className={cn(
                "inline-flex h-4 items-center rounded-full px-2 text-[10px] font-medium transition-colors",
                settings.telemetryEnabled
                  ? "bg-accent/20 text-accent"
                  : "bg-white/10 text-white/40",
              )}
            >
              {settings.telemetryEnabled ? "Enabled" : "Disabled"}
            </span>
          </div>
          <button
            type="button"
            onClick={() => api.quitApp()}
            className="group flex h-9 w-full items-center gap-3 rounded-control px-3 text-left type-label text-white/50 transition-colors duration-150 hover:bg-white/5 hover:text-white"
          >
            <Power
              size={17}
              strokeWidth={2}
              className="shrink-0 text-white/45 transition-colors group-hover:text-red-400"
            />
            Quit SpeakType
          </button>
        </div>
      )}

      {/* Studio wordmark, letters spread across the sidebar's width. */}
      <a
        href="https://2048labs.com"
        target="_blank"
        rel="noreferrer"
        aria-label="2048 Labs"
        className="mx-5 mb-6 flex justify-between border-t border-white/10 pt-5 type-section text-white/25 transition-colors hover:text-white/60"
      >
        {"2048 LABS".split("").map((char, i) => (
          <span key={i} aria-hidden className={char === " " ? "w-2" : undefined}>
            {char}
          </span>
        ))}
      </a>
    </nav>
  );
}
