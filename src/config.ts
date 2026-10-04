/** App-wide constants. Changing storage names or the model pin affects existing users. */

export const MODEL = {
  id: "Xenova/clip-vit-base-patch32",
  /** Pinned Hugging Face commit, so a change to the model repo can't silently change what runs. */
  revision: "d15189d7028b43f1d3e65039190477f6af591c2a",
  /**
   * 8-bit weights on the CPU runtime. Measured on real photos, the fp16 weights
   * used with WebGPU lose too much precision for CLIP and rank poorly.
   */
  dtype: "q8",
  /** Stored with each embedding; embeddings from any other model are recomputed. */
  embeddingVersion: "clip-vit-base-patch32@d15189d:q8",
  /** Shown to users before the one-time download. */
  approximateDownload: "about 150 MB",
} as const;

/**
 * When a photo counts as a match, in raw CLIP cosine similarity. Calibrated for
 * the model above on labelled real photos: a photo is a close match if it scores
 * at least `semanticFloor` and is within `semanticMargin` of the best photo.
 * Change these together with the model.
 */
export const MATCHING = {
  semanticFloor: 0.235,
  semanticMargin: 0.03,
  /** Share of query words that must appear in a file name to count as a match. */
  fileNameMatch: 0.5,
} as const;

export const STORAGE = {
  databaseName: "mnesia-local-library",
  databaseVersion: 1,
  recordStore: "records",
  settingsKey: "mnesia-settings",
} as const;

export const LIMITS = {
  /** Longest edge of stored previews and of the image the model sees. */
  previewMaxSide: 720,
  previewQuality: 0.88,
  /** A file that takes longer than this to decode is skipped instead of stalling the import. */
  decodeTimeoutMs: 20_000,
  /** Results are rendered in pages so very large libraries stay responsive. */
  resultsPageSize: 120,
  queryEmbeddingCacheSize: 64,
  searchDebounceMs: 220,
  /** Long enough to read comfortably at a relaxed pace. */
  toastDurationMs: 6_000,
} as const;
