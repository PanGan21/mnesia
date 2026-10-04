import { describe, expect, it } from "vitest";
import { makeRecord } from "../test/fixtures";
import {
  buildSearchTokens,
  cosineSimilarity,
  lexicalOverlap,
  rankRecords,
  sortRanked,
  tokenize,
} from "./ranking";

describe("tokenize", () => {
  it("splits on punctuation and folds simple plurals", () => {
    expect(tokenize("Dogs_at-the.Park")).toEqual(["dog", "at", "the", "park"]);
    expect(tokenize("glass bus")).toEqual(["glass", "bus"]);
  });

  it("keeps letters from any script", () => {
    expect(tokenize("Αθήνα_2024 café")).toEqual(["αθήνα", "2024", "café"]);
  });
});

describe("buildSearchTokens", () => {
  it("includes name words, kind and date words but not the extension", () => {
    const tokens = buildSearchTokens("beach-day.jpeg", new Date(2025, 6, 4).getTime(), "image");
    expect(tokens).toEqual(
      expect.arrayContaining(["beach", "day", "image", "jul", "2025", "summer"]),
    );
    expect(tokens).not.toContain("jpeg");
  });
});

describe("similarity", () => {
  it("computes cosine similarity and handles degenerate input", () => {
    expect(cosineSimilarity([1, 0], [1, 0])).toBeCloseTo(1);
    expect(cosineSimilarity([1, 0], [0, 1])).toBeCloseTo(0);
    expect(cosineSimilarity([1, 0], [1])).toBe(0);
    expect(cosineSimilarity([0, 0], [1, 0])).toBe(0);
  });

  it("measures the share of query words found", () => {
    expect(lexicalOverlap(["dog", "park"], ["dog", "beach"])).toBe(0.5);
    expect(lexicalOverlap([], ["dog"])).toBe(0);
  });
});

/** A unit vector whose cosine with [1, 0] is exactly `similarity`. */
const vectorAt = (similarity: number) =>
  Float32Array.from([similarity, Math.sqrt(1 - similarity ** 2)]);
const query = Float32Array.from([1, 0]);

describe("rankRecords", () => {
  it("matches by file-name words when there's no embedding", () => {
    const dog = makeRecord({ name: "dog-park.jpg" });
    const cake = makeRecord({ name: "cake.jpg" });
    const ranked = rankRecords([dog, cake], "dogs", null);
    expect(ranked.map((result) => result.record.id)).toEqual([dog.id]);
    expect(ranked[0]?.isMatch).toBe(true);
  });

  it("marks close matches by meaning and keeps the rest as candidates", () => {
    const best = makeRecord({ embedding: vectorAt(0.3) });
    const close = makeRecord({ embedding: vectorAt(0.28) });
    const unrelated = makeRecord({ embedding: vectorAt(0.2) });
    const ranked = sortRanked(rankRecords([unrelated, close, best], "x", query), "relevance");

    expect(ranked.map((result) => [result.record.id, result.isMatch])).toEqual([
      [best.id, true],
      [close.id, true],
      [unrelated.id, false],
    ]);
  });

  it("doesn't call anything a match when nothing is close in absolute terms", () => {
    const ranked = rankRecords(
      [makeRecord({ embedding: vectorAt(0.22) }), makeRecord({ embedding: vectorAt(0.21) })],
      "snow",
      query,
    );
    expect(ranked.every((result) => !result.isMatch)).toBe(true);
  });

  it("only matches photos close to the best one", () => {
    const ranked = rankRecords(
      [makeRecord({ embedding: vectorAt(0.31) }), makeRecord({ embedding: vectorAt(0.24) })],
      "x",
      query,
    );
    expect(ranked.map((result) => result.isMatch)).toEqual([true, false]);
  });

  it("always matches a file name containing the words", () => {
    const named = makeRecord({ name: "snow-day.jpg", embedding: vectorAt(0.1) });
    const [ranked] = rankRecords([named, makeRecord({ embedding: vectorAt(0.3) })], "snow", query);
    expect(ranked?.isMatch).toBe(true);
  });

  it("treats items without an embedding as unmatched by meaning", () => {
    const [ranked] = rankRecords([makeRecord()], "x", query);
    expect(ranked?.isMatch).toBe(false);
  });
});

describe("sortRanked", () => {
  const older = {
    record: makeRecord({ name: "b.jpg", lastModified: 1 }),
    score: 0.9,
    isMatch: true,
  };
  const newer = {
    record: makeRecord({ name: "a10.jpg", lastModified: 2 }),
    score: 0.9,
    isMatch: true,
  };
  const best = { record: makeRecord({ name: "a2.jpg", lastModified: 0 }), score: 1, isMatch: true };
  const candidate = {
    record: makeRecord({ name: "c.jpg", lastModified: 3 }),
    score: 0.95,
    isMatch: false,
  };

  it("puts matches first, then orders by score and date", () => {
    expect(sortRanked([candidate, older, newer, best], "relevance")).toEqual([
      best,
      newer,
      older,
      candidate,
    ]);
  });

  it("orders by date and by natural name order", () => {
    expect(sortRanked([older, newer, best], "newest")).toEqual([newer, older, best]);
    expect(sortRanked([older, newer, best], "oldest")).toEqual([best, older, newer]);
    expect(sortRanked([older, newer, best], "name")).toEqual([best, newer, older]);
  });
});
