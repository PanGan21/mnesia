import type { MonthKey, Season, TimeFilter } from "../types";

const MONTH_KEYS: readonly MonthKey[] = [
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
];

const DAY_MS = 24 * 60 * 60 * 1000;

export function monthKeyOf(date: Date): MonthKey {
  // getMonth() is always 0–11, so the lookup can't miss.
  return MONTH_KEYS[date.getMonth()] as MonthKey;
}

/** Northern-hemisphere meteorological seasons. */
export function seasonOf(date: Date): Season {
  const month = date.getMonth();
  if (month === 11 || month <= 1) {
    return "winter";
  }
  if (month <= 4) {
    return "spring";
  }
  if (month <= 7) {
    return "summer";
  }
  return "autumn";
}

export function matchesTimeFilter(
  timestamp: number,
  filter: TimeFilter,
  now = new Date(),
): boolean {
  if (filter === "all") {
    return true;
  }

  const date = new Date(timestamp);

  switch (filter) {
    case "30d":
      return timestamp >= now.getTime() - 30 * DAY_MS && timestamp <= now.getTime();
    case "this-year":
      return date.getFullYear() === now.getFullYear();
    case "last-year":
      return date.getFullYear() === now.getFullYear() - 1;
    case "winter":
    case "spring":
    case "summer":
    case "autumn":
      return seasonOf(date) === filter;
    default:
      return monthKeyOf(date) === filter;
  }
}
