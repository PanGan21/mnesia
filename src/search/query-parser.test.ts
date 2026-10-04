import { describe, expect, it } from "vitest";
import { parseQuery } from "./query-parser";

describe("parseQuery", () => {
  it("extracts media type and time hints and keeps the rest", () => {
    expect(parseQuery("videos of the beach last summer")).toEqual({
      text: "beach",
      mediaKind: "video",
      timeFilter: "summer",
      understood: ["Videos", "Summer"],
    });
  });

  it("prefers multi-word time phrases", () => {
    const parsed = parseQuery("birthday cake last year");
    expect(parsed.timeFilter).toBe("last-year");
    expect(parsed.text).toBe("birthday cake");
  });

  it.each([
    ["waterfall", "waterfall"],
    ["springfield trip", "springfield trip"],
    ["eclipse", "eclipse"],
    ["photography class", "photography class"],
    ["marching band", "marching band"],
    ["decorations", "decorations"],
  ])("only matches whole words: %s", (query, text) => {
    const parsed = parseQuery(query);
    expect(parsed.text).toBe(text);
    expect(parsed.mediaKind).toBeNull();
    expect(parsed.timeFilter).toBeNull();
  });

  it("treats letters from any script as word characters", () => {
    expect(parseQuery("mayβ").timeFilter).toBeNull();
  });

  it("is case-insensitive", () => {
    const parsed = parseQuery("Photos from APRIL");
    expect(parsed.mediaKind).toBe("image");
    expect(parsed.timeFilter).toBe("apr");
  });

  it("keeps the original text when the query is only filter words", () => {
    const parsed = parseQuery("videos");
    expect(parsed.mediaKind).toBe("video");
    expect(parsed.text).toBe("videos");
  });

  it("is stable across repeated calls", () => {
    for (let i = 0; i < 3; i += 1) {
      expect(parseQuery("photos in may").timeFilter).toBe("may");
    }
  });
});
