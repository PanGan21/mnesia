import { STORAGE } from "../config";
import { MEDIA_FILTERS, TIME_FILTERS, type MediaFilter, type TimeFilter } from "../types";

export interface Settings {
  persistLibrary: boolean;
  mediaFilter: MediaFilter;
  timeFilter: TimeFilter;
}

export const DEFAULT_SETTINGS: Readonly<Settings> = {
  persistLibrary: true,
  mediaFilter: "all",
  timeFilter: "all",
};

function oneOf<T extends string>(allowed: readonly T[], value: unknown, fallback: T): T {
  return allowed.includes(value as T) ? (value as T) : fallback;
}

/** Settings are a convenience: unreadable or unavailable storage falls back to defaults. */
export function loadSettings(storage: Pick<Storage, "getItem"> = localStorage): Settings {
  try {
    const parsed: unknown = JSON.parse(storage.getItem(STORAGE.settingsKey) ?? "null");
    if (typeof parsed !== "object" || parsed === null) {
      return { ...DEFAULT_SETTINGS };
    }
    const raw = parsed as Record<string, unknown>;
    return {
      persistLibrary:
        typeof raw.persistLibrary === "boolean"
          ? raw.persistLibrary
          : DEFAULT_SETTINGS.persistLibrary,
      mediaFilter: oneOf(MEDIA_FILTERS, raw.mediaFilter, DEFAULT_SETTINGS.mediaFilter),
      timeFilter: oneOf(TIME_FILTERS, raw.timeFilter, DEFAULT_SETTINGS.timeFilter),
    };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(
  settings: Settings,
  storage: Pick<Storage, "setItem"> = localStorage,
): void {
  try {
    storage.setItem(STORAGE.settingsKey, JSON.stringify(settings));
  } catch {
    // Private browsing or blocked storage: settings simply won't be remembered.
  }
}
