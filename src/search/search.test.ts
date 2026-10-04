import { describe, expect, it, vi } from "vitest";
import { makeRecord } from "../test/fixtures";
import { search, type SearchRequest } from "./search";

const request = (overrides: Partial<SearchRequest> = {}): SearchRequest => ({
  query: "",
  mediaFilter: "all",
  timeFilter: "all",
  sortOrder: "relevance",
  ...overrides,
});

describe("search", () => {
  const photo = makeRecord({ name: "beach.jpg", lastModified: new Date(2025, 6, 1).getTime() });
  const video = makeRecord({
    name: "beach-clip.mp4",
    mediaKind: "video",
    lastModified: new Date(2025, 0, 1).getTime(),
  });

  it("lists everything newest first without a query", async () => {
    const outcome = await search([video, photo], request(), null);
    expect(outcome.results.map((result) => result.record.id)).toEqual([photo.id, video.id]);
    expect(outcome.semantic).toBe(false);
  });

  it("lets words in the query override the controls", async () => {
    const outcome = await search(
      [video, photo],
      request({ query: "beach videos", mediaFilter: "image" }),
      null,
    );
    expect(outcome.results.map((result) => result.record.id)).toEqual([video.id]);
    expect(outcome.parsed.understood).toEqual(["Videos"]);
  });

  it("separates close matches from other candidates", async () => {
    const match = makeRecord({ embedding: Float32Array.from([1, 0]) });
    const other = makeRecord({ embedding: Float32Array.from([0, 1]) });
    const outcome = await search([other, match], request({ query: "something" }), () =>
      Promise.resolve(Float32Array.from([1, 0])),
    );
    expect(outcome.results.map((result) => result.record.id)).toEqual([match.id]);
    expect(outcome.others.map((result) => result.record.id)).toEqual([other.id]);
  });

  it("embeds only the descriptive part of the query", async () => {
    const embed = vi.fn(() => Promise.resolve(Float32Array.from([1, 0])));
    const outcome = await search([photo], request({ query: "beach in july" }), embed);
    expect(embed).toHaveBeenCalledWith("beach");
    expect(outcome.semantic).toBe(true);
  });
});
