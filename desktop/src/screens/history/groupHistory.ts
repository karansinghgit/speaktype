import type { HistoryItem } from "@/lib/api";
import { startOfDay } from "@/lib/format";

/** Filters transcripts and groups them by local day, preserving their input order. */
export function groupHistory(items: readonly HistoryItem[], query: string): [number, HistoryItem[]][] {
  const q = query.trim().toLowerCase();
  const byDay = new Map<number, HistoryItem[]>();
  for (const item of items) {
    if (q && !item.transcript.toLowerCase().includes(q)) continue;
    const day = startOfDay(item.createdAt);
    const group = byDay.get(day);
    if (group) group.push(item);
    else byDay.set(day, [item]);
  }
  return [...byDay.entries()];
}
