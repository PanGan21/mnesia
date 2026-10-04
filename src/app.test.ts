import { describe, expect, it } from "vitest";
import { describeImport } from "./app";

const base = {
  added: 0,
  addedVideos: 0,
  duplicates: 0,
  unreadable: 0,
  ignored: 0,
  stopped: null,
} as const;

describe("describeImport", () => {
  it("summarises a normal import", () => {
    expect(describeImport({ ...base, added: 3 })).toBe("Added 3 photos.");
    expect(describeImport({ ...base, added: 3, addedVideos: 1 })).toBe(
      "Added 3 photos and videos.",
    );
  });

  it("mentions duplicates and unreadable files", () => {
    expect(describeImport({ ...base, added: 1, duplicates: 2, unreadable: 1 })).toBe(
      "Added 1 photo. 2 were already here. 1 file couldn’t be opened and was skipped.",
    );
  });

  it("explains when nothing could be added", () => {
    expect(describeImport({ ...base, ignored: 2 })).toBe(
      "Those files aren’t photos or videos, so nothing was added.",
    );
  });

  it("explains stops", () => {
    expect(describeImport({ ...base, added: 1, stopped: "canceled" })).toBe(
      "Stopped. Added 1 photo.",
    );
    expect(describeImport({ ...base, added: 2, stopped: "storage-full" })).toContain(
      "out of space",
    );
  });
});
