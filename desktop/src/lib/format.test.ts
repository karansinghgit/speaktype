import { describe, expect, it } from "vitest";
import {
  accuracyTier,
  countWords,
  describeImport,
  formatBytes,
  formatClock,
  formatCompact,
  formatDay,
  formatDuration,
  formatMinutesSaved,
  formatLanguages,
  formatModelSize,
  formatNumber,
  formatRelative,
  formatTime,
  hotkeyParts,
  plural,
  speedTier,
  startOfDay,
} from "./format";

describe("durations and sizes", () => {
  it("formats clocks and durations", () => {
    expect(formatClock(0)).toBe("0:00");
    expect(formatClock(75.9)).toBe("1:15");
    expect(formatClock(-3)).toBe("0:00");
    expect(formatDuration(12)).toBe("12s");
    expect(formatDuration(95)).toBe("1m 35s");
    expect(formatDuration(4500)).toBe("1h 15m");
    expect(formatMinutesSaved(999)).toBe("999m");
    expect(formatMinutesSaved(1179)).toBe("19.7h");
    expect(formatMinutesSaved(1200)).toBe("20h");
    expect(formatMinutesSaved(12000)).toBe("200h");
  });

  it("formats model and byte sizes", () => {
    expect(formatModelSize(0)).toBe("0 MB");
    expect(formatModelSize(142)).toBe("142 MB");
    expect(formatModelSize(999)).toBe("999 MB");
    expect(formatModelSize(1000)).toBe("1000 MB");
    expect(formatModelSize(1023)).toBe("1023 MB");
    expect(formatModelSize(1024)).toBe("1.0 GB");
    expect(formatModelSize(1536)).toBe("1.5 GB");
    expect(formatModelSize(1624)).toBe("1.6 GB");
    expect(formatModelSize(2048)).toBe("2.0 GB");
    expect(formatBytes(500)).toBe("1 KB");
    expect(formatBytes(5 * 1024 ** 2)).toBe("5 MB");
    expect(formatBytes(2.5 * 1024 ** 3)).toBe("2.50 GB");
  });

  it("formats compact numbers", () => {
    expect(formatCompact(0)).toBe("0");
    expect(formatCompact(500)).toBe("500");
    expect(formatCompact(1200)).toBe(
      new Intl.NumberFormat(undefined, { notation: "compact", maximumFractionDigits: 1 }).format(1200),
    );
  });
});

describe("relative times and dates", () => {
  const now = new Date(2026, 8, 17, 12, 0, 0).getTime();
  it("describes how long ago", () => {
    expect(formatRelative(now - 10_000, now)).toBe("just now");
    expect(formatRelative(now - 5 * 60_000, now)).toBe("5m ago");
    expect(formatRelative(now - 3 * 3_600_000, now)).toBe("3h ago");
    expect(formatRelative(now - 2 * 86_400_000, now)).toBe("2d ago");
    // Clock skew into the future doesn't produce negative values.
    expect(formatRelative(now + 60_000, now)).toBe("just now");
  });

  it("finds the start of the local day", () => {
    expect(startOfDay(now)).toBe(new Date(2026, 8, 17).getTime());
  });

  it("formats time of day", () => {
    expect(formatTime(now)).toBe(
      new Date(now).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }),
    );
  });

  it("formats day labels", () => {
    const today = new Date();
    const todayMs = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12, 0, 0).getTime();
    const yesterdayMs = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1, 12, 0, 0).getTime();
    const threeDaysAgo = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 3, 12, 0, 0);
    const pastYear = new Date(today.getFullYear() - 1, 5, 15, 12, 0, 0);

    expect(formatDay(todayMs)).toBe("Today");
    expect(formatDay(yesterdayMs)).toBe("Yesterday");
    expect(formatDay(threeDaysAgo.getTime())).toBe(
      threeDaysAgo.toLocaleDateString([], { weekday: "long" }),
    );
    expect(formatDay(pastYear.getTime())).toBe(
      pastYear.toLocaleDateString([], {
        month: "long",
        day: "numeric",
        year: "numeric",
      }),
    );
  });
});

describe("models", () => {
  it("names speed and accuracy tiers", () => {
    expect(speedTier(9.7)).toBe("Blazing");
    expect(speedTier(7.5)).toBe("Fast");
    expect(accuracyTier(9.4)).toBe("Flawless");
    expect(accuracyTier(6)).toBe("Rough");
  });

  it("describes language coverage", () => {
    expect(formatLanguages({ englishOnly: true, languages: ["en"] })).toBe("English only");
    expect(formatLanguages({ englishOnly: false, languages: ["de", "fr"] })).toBe("2 languages");
    expect(formatLanguages({ englishOnly: false, languages: null })).toBe("99 languages");
  });
});

describe("text", () => {
  it("counts words", () => {
    expect(countWords("")).toBe(0);
    expect(countWords("    ")).toBe(0);
    expect(countWords("single")).toBe(1);
    expect(countWords("  hello   world \n again ")).toBe(3);
  });

  it("formats plurals and numbers", () => {
    expect(plural(1, "transcription")).toBe("1 transcription");
    expect(plural(0, "transcription")).toBe("0 transcriptions");
    expect(plural(2, "transcription")).toBe("2 transcriptions");
    expect(plural(1000, "word")).toBe(`${(1000).toLocaleString()} words`);
    expect(formatNumber(0)).toBe("0");
    expect(formatNumber(1234)).toBe((1234).toLocaleString());
  });

  it("splits single-modifier and combined hotkeys", () => {
    expect(hotkeyParts("Fn")).toEqual(["fn"]);
    expect(hotkeyParts("RightCommand")).toEqual(["Right ⌘"]);
    expect(hotkeyParts("Ctrl+Space")).toHaveLength(2);
  });
});

describe("imports", () => {
  it("describes what came over", () => {
    expect(describeImport({ transcripts: 21, dictionary: 1, settings: true })).toBe(
      "21 transcriptions, 1 dictionary word and your settings",
    );
    expect(describeImport({ transcripts: 1, dictionary: 0 })).toBe("1 transcription");
    expect(describeImport({ transcripts: 0, dictionary: 0, settings: false })).toBe("");
  });
});
