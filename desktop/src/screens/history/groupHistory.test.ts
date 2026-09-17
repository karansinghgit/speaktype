import { describe, expect, it } from "vitest";
import type { HistoryItem } from "@/lib/api";
import { groupHistory } from "./groupHistory";

const item = (id: string, createdAt: number, transcript = id): HistoryItem => ({
  id,
  createdAt,
  transcript,
  durationSecs: 1,
  model: "Tiny",
  wordCount: 1,
  audioPath: null,
});

describe("groupHistory", () => {
  it("handles empty history and searches without matches", () => {
    expect(groupHistory([], "")).toEqual([]);
    expect(groupHistory([item("a", 0, "hello")], "missing")).toEqual([]);
  });

  it("groups by local calendar day and preserves day and transcript order", () => {
    const newest = item("a", new Date(2026, 8, 17, 23, 59).getTime());
    const sameDay = item("b", new Date(2026, 8, 17, 0, 0).getTime());
    const previousDay = item("c", new Date(2026, 8, 16, 23, 59).getTime());
    expect(groupHistory([newest, sameDay, previousDay], "")).toEqual([
      [new Date(2026, 8, 17).getTime(), [newest, sameDay]],
      [new Date(2026, 8, 16).getTime(), [previousDay]],
    ]);
  });

  it("trims the query, ignores case, and omits days with no matches", () => {
    const first = item("a", new Date(2026, 8, 17, 12).getTime(), "Hello WORLD");
    const excluded = item("b", new Date(2026, 8, 17, 11).getTime(), "unrelated");
    const otherDay = item("c", new Date(2026, 8, 16, 12).getTime(), "unrelated");
    const last = item("d", new Date(2026, 8, 15, 12).getTime(), "worldwide");
    expect(groupHistory([first, excluded, otherDay, last], "  WoRlD  ")).toEqual([
      [new Date(2026, 8, 17).getTime(), [first]],
      [new Date(2026, 8, 15).getTime(), [last]],
    ]);
  });

  it("treats whitespace-only queries as no filter without mutating the source", () => {
    const first = Object.freeze(item("a", 0));
    const second = Object.freeze(item("b", 1));
    const source = Object.freeze([first, second]);
    const groups = groupHistory(source, " \n ");
    expect(groups[0][1]).toEqual(source);
    expect(groups[0][1][0]).toBe(first);
    groups[0][1].pop();
    expect(source).toEqual([first, second]);
    expect(groupHistory(source, "")[0][1]).toHaveLength(2);
  });

  it("keeps every transcript in a large same-day history", () => {
    const start = new Date(2026, 8, 17).getTime();
    const items = Array.from({ length: 20_000 }, (_, i) => item(String(i), start + i));
    expect(groupHistory(items, "")).toEqual([[start, items]]);
  });
});
