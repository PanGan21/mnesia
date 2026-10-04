import { describe, expect, it } from "vitest";
import { DEFAULT_SETTINGS, loadSettings, saveSettings } from "./settings";

function memoryStorage(initial: string | null = null) {
  let value = initial;
  return {
    getItem: () => value,
    setItem: (_key: string, next: string) => {
      value = next;
    },
  };
}

describe("settings", () => {
  it("round-trips valid settings", () => {
    const storage = memoryStorage();
    const settings = {
      persistLibrary: false,
      mediaFilter: "video",
      timeFilter: "may",
    } as const;
    saveSettings(settings, storage);
    expect(loadSettings(storage)).toEqual(settings);
  });

  it("replaces unknown values with defaults", () => {
    const storage = memoryStorage(
      JSON.stringify({
        persistLibrary: "yes",
        mediaFilter: "audio",
        timeFilter: "never",
      }),
    );
    expect(loadSettings(storage)).toEqual(DEFAULT_SETTINGS);
  });

  it("survives corrupt or unavailable storage", () => {
    expect(loadSettings(memoryStorage("{not json"))).toEqual(DEFAULT_SETTINGS);
    const throwing = {
      getItem: () => {
        throw new Error("blocked");
      },
      setItem: () => {
        throw new Error("blocked");
      },
    };
    expect(loadSettings(throwing)).toEqual(DEFAULT_SETTINGS);
    expect(() => saveSettings(DEFAULT_SETTINGS, throwing)).not.toThrow();
  });
});
