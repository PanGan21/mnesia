export type MediaKind = "image" | "video";

export const TIME_FILTERS = [
  "all",
  "30d",
  "this-year",
  "last-year",
  "winter",
  "spring",
  "summer",
  "autumn",
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
] as const;
export type TimeFilter = (typeof TIME_FILTERS)[number];
export type Season = "winter" | "spring" | "summer" | "autumn";
export type MonthKey = Extract<
  TimeFilter,
  "jan" | "feb" | "mar" | "apr" | "may" | "jun" | "jul" | "aug" | "sep" | "oct" | "nov" | "dec"
>;

export const MEDIA_FILTERS = ["all", "image", "video"] as const;
export type MediaFilter = (typeof MEDIA_FILTERS)[number];

export const SORT_ORDERS = ["relevance", "newest", "oldest", "name"] as const;
export type SortOrder = (typeof SORT_ORDERS)[number];

/** One photo or video in the local library. */
export interface MediaRecord {
  id: string;
  name: string;
  mediaKind: MediaKind;
  mimeType: string;
  size: number;
  /** File modification time, used as the "taken" date. */
  lastModified: number;
  addedAt: number;
  /** Identifies the same file imported twice: name, size and modification time. */
  fingerprint: string;
  previewDataUrl: string;
  width: number;
  height: number;
  /** Seconds, for videos. */
  duration: number | null;
  /** The original file, kept so the viewer can show full quality. */
  fileBlob: Blob | null;
  /** CLIP image embedding; null until smart search has processed this item. */
  embedding: Float32Array | null;
  /** Which model produced the embedding (MODEL.embeddingVersion). */
  embeddingModel: string | null;
  searchTokens: string[];
}

export interface RankedRecord {
  record: MediaRecord;
  score: number;
  /** A close match, as opposed to merely the closest of what's there. */
  isMatch: boolean;
}
