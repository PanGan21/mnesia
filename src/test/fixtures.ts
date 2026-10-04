import { buildSearchTokens } from "../search/ranking";
import type { MediaRecord } from "../types";

let counter = 0;

/** A valid record with sensible defaults; override what a test cares about. */
export function makeRecord(overrides: Partial<MediaRecord> = {}): MediaRecord {
  counter += 1;
  const name = overrides.name ?? `photo-${counter}.jpg`;
  const lastModified = overrides.lastModified ?? Date.UTC(2025, 5, 1);
  const mediaKind = overrides.mediaKind ?? "image";
  return {
    id: `id-${counter}`,
    name,
    mediaKind,
    mimeType: "image/jpeg",
    size: 1000,
    lastModified,
    addedAt: counter,
    fingerprint: `${name}|1000|${lastModified}`,
    previewDataUrl: "data:image/jpeg;base64,AAAA",
    width: 4,
    height: 3,
    duration: null,
    fileBlob: null,
    embedding: null,
    embeddingModel: null,
    searchTokens: buildSearchTokens(name, lastModified, mediaKind),
    ...overrides,
  };
}
