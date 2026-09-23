import { Pause, Play } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Spinner } from "@/components/ui";
import { api } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatClock } from "@/lib/format";

const BAR_COUNT = 96;

/** Plays a history item's recording, with a clickable waveform drawn from the real audio. */
export function AudioPlayer({ itemId }: { itemId: string }) {
  const audio = useRef<HTMLAudioElement | null>(null);
  const [peaks, setPeaks] = useState<number[]>();
  const [error, setError] = useState<string>();
  const [playing, setPlaying] = useState(false);
  const [time, setTime] = useState(0);
  const [duration, setDuration] = useState(0);

  useEffect(() => {
    let url: string | undefined;
    let cancelled = false;
    api
      .readHistoryAudio(itemId)
      .then(async (buffer) => {
        if (cancelled) return;
        url = URL.createObjectURL(new Blob([buffer], { type: "audio/wav" }));
        const element = new Audio(url);
        element.ontimeupdate = () => setTime(element.currentTime);
        element.onloadedmetadata = () => setDuration(element.duration);
        element.onplay = () => setPlaying(true);
        element.onpause = () => setPlaying(false);
        element.onended = () => {
          setPlaying(false);
          element.currentTime = 0;
        };
        audio.current = element;
        setPeaks(await computePeaks(buffer));
      })
      .catch((e) => !cancelled && setError(String(e)));

    return () => {
      cancelled = true;
      audio.current?.pause();
      audio.current = null;
      if (url) URL.revokeObjectURL(url);
    };
  }, [itemId]);

  // Smooth progress while playing; `timeupdate` only fires a few times a second.
  useEffect(() => {
    if (!playing) return;
    let frame = requestAnimationFrame(function tick() {
      if (audio.current) setTime(audio.current.currentTime);
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [playing]);

  if (error) {
    return <p className="type-small text-ink-muted">The recording for this transcript is missing.</p>;
  }

  const progress = duration ? time / duration : 0;
  return (
    <div className="flex items-center gap-4 rounded-card border border-line-subtle bg-surface-sunken px-3 py-2.5">
      <button
        type="button"
        aria-label={playing ? "Pause" : "Play"}
        disabled={!peaks}
        onClick={() => (audio.current?.paused ? audio.current.play() : audio.current?.pause())}
        className="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary text-on-primary transition-transform active:scale-95 disabled:opacity-50"
      >
        {!peaks ? <Spinner size={14} /> : playing ? <Pause size={15} fill="currentColor" /> : <Play size={15} fill="currentColor" className="ml-0.5" />}
      </button>

      <div
        role="slider"
        aria-label="Playback position"
        aria-valuemin={0}
        aria-valuemax={Math.round(duration)}
        aria-valuenow={Math.round(time)}
        aria-valuetext={`${formatClock(time)} of ${formatClock(duration)}`}
        tabIndex={peaks ? 0 : -1}
        onClick={(e) => {
          if (!audio.current || !duration) return;
          const rect = e.currentTarget.getBoundingClientRect();
          audio.current.currentTime = ((e.clientX - rect.left) / rect.width) * duration;
          setTime(audio.current.currentTime);
        }}
        onKeyDown={(e) => {
          if (!audio.current || !duration) return;
          const STEP = 5;
          if (e.key === "ArrowLeft") {
            e.preventDefault();
            audio.current.currentTime = Math.max(0, audio.current.currentTime - STEP);
            setTime(audio.current.currentTime);
          } else if (e.key === "ArrowRight") {
            e.preventDefault();
            audio.current.currentTime = Math.min(duration, audio.current.currentTime + STEP);
            setTime(audio.current.currentTime);
          } else if (e.key === "Home") {
            e.preventDefault();
            audio.current.currentTime = 0;
            setTime(0);
          } else if (e.key === "End") {
            e.preventDefault();
            audio.current.currentTime = duration;
            setTime(duration);
          } else if (e.key === " " || e.key === "Enter") {
            e.preventDefault();
            audio.current.paused ? audio.current.play() : audio.current.pause();
          }
        }}
        className="flex h-10 flex-1 items-center gap-[2px] rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50"
      >
        {(peaks ?? new Array(BAR_COUNT).fill(0.08)).map((peak, i) => (
          <span
            key={i}
            className={cn(
              "flex-1 rounded-full transition-colors duration-75",
              i / BAR_COUNT < progress ? "bg-accent" : "bg-line-strong",
            )}
            style={{ height: `${Math.max(8, peak * 100)}%` }}
          />
        ))}
      </div>

      <span className="w-[76px] shrink-0 text-right type-caption text-ink-muted tabular-nums">
        {formatClock(time)} / {formatClock(duration)}
      </span>
    </div>
  );
}

async function computePeaks(buffer: ArrayBuffer): Promise<number[]> {
  const context = new OfflineAudioContext(1, 1, 16_000);
  const decoded = await context.decodeAudioData(buffer.slice(0));
  const data = decoded.getChannelData(0);
  const size = Math.max(1, Math.floor(data.length / BAR_COUNT));
  const peaks = Array.from({ length: BAR_COUNT }, (_, i) => {
    let max = 0;
    for (let j = i * size; j < Math.min(data.length, (i + 1) * size); j++) max = Math.max(max, Math.abs(data[j]));
    return max;
  });
  const loudest = Math.max(0.05, ...peaks);
  return peaks.map((p) => p / loudest);
}
