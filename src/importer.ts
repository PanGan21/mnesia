import { MODEL } from "./config";
import { fingerprintOf, StorageFullError } from "./storage/library-store";
import type { Library } from "./library";
import { isSupportedMedia } from "./media/files";
import { createPreview } from "./media/previews";
import { ModelResetError, type ModelClient } from "./model/model-client";
import { buildSearchTokens } from "./search/ranking";
import type { MediaKind, MediaRecord } from "./types";

export type ImportProgress =
  | { stage: "model"; percent: number }
  | { stage: "files"; index: number; total: number; fileName: string };

export interface ImportSummary {
  added: number;
  /** How many of the added items are videos. */
  addedVideos: number;
  /** Already in the library, or listed twice in this import. */
  duplicates: number;
  /** Media the browser couldn't decode. */
  unreadable: number;
  /** Files that aren't photos or videos. */
  ignored: number;
  stopped: "canceled" | "storage-full" | null;
}

interface ImportOptions {
  signal: AbortSignal;
  onProgress: (progress: ImportProgress) => void;
  onAdded: (record: MediaRecord) => void;
}

function isAborted(signal: AbortSignal): boolean {
  return signal.aborted;
}

function createId(): string {
  return typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

/**
 * Adds files to the library: makes a preview of each, embeds it with the model
 * when it's available, and saves it. Files are processed one at a time so
 * memory stays flat for large imports.
 */
export async function importFiles(
  files: readonly File[],
  library: Library,
  model: ModelClient,
  { signal, onProgress, onAdded }: ImportOptions,
): Promise<ImportSummary> {
  const summary: ImportSummary = {
    added: 0,
    addedVideos: 0,
    duplicates: 0,
    unreadable: 0,
    ignored: 0,
    stopped: null,
  };

  const queue: File[] = [];
  const seen = new Set<string>();
  for (const file of files) {
    if (!isSupportedMedia(file)) {
      summary.ignored += 1;
      continue;
    }
    const fingerprint = fingerprintOf(file);
    if (library.contains(fingerprint) || seen.has(fingerprint)) {
      summary.duplicates += 1;
      continue;
    }
    seen.add(fingerprint);
    queue.push(file);
  }

  if (queue.length === 0) {
    return summary;
  }

  if (!model.isReady && !model.isUnavailable) {
    const unsubscribe = model.subscribe((state) => {
      if (state.status === "loading") {
        onProgress({ stage: "model", percent: state.percent });
      }
    });
    try {
      await model.ensureReady();
    } finally {
      unsubscribe();
    }
  }

  for (const [index, file] of queue.entries()) {
    if (signal.aborted) {
      summary.stopped = "canceled";
      break;
    }
    onProgress({ stage: "files", index, total: queue.length, fileName: file.name });

    const kind: MediaKind = file.type.startsWith("video/") ? "video" : "image";
    let record: MediaRecord;
    try {
      const preview = await createPreview(file, kind);
      const embedding = model.isReady ? await model.embedImage(preview.dataUrl) : null;
      const lastModified = file.lastModified || Date.now();
      record = {
        id: createId(),
        name: file.name,
        mediaKind: kind,
        mimeType: file.type,
        size: file.size,
        lastModified,
        addedAt: Date.now(),
        fingerprint: fingerprintOf(file),
        previewDataUrl: preview.dataUrl,
        width: preview.width,
        height: preview.height,
        duration: preview.duration,
        fileBlob: file,
        embedding,
        embeddingModel: embedding ? MODEL.embeddingVersion : null,
        searchTokens: buildSearchTokens(file.name, lastModified, kind),
      };
    } catch (error) {
      // Re-read the signal: it may have been aborted while the preview or embedding was pending.
      if (error instanceof ModelResetError || isAborted(signal)) {
        summary.stopped = "canceled";
        break;
      }
      console.warn(`Skipped ${file.name}:`, error);
      summary.unreadable += 1;
      continue;
    }

    try {
      await library.add(record);
      summary.added += 1;
      summary.addedVideos += record.mediaKind === "video" ? 1 : 0;
      onAdded(record);
    } catch (error) {
      if (error instanceof StorageFullError) {
        // The record is still usable this session; stop before filling memory further.
        summary.added += 1;
        summary.addedVideos += record.mediaKind === "video" ? 1 : 0;
        onAdded(record);
        summary.stopped = "storage-full";
        break;
      }
      throw error;
    }
  }

  return summary;
}

/**
 * Gives smart search the items it hasn't processed yet: ones added while it was
 * unavailable, and ones processed by an older model. Works from the stored
 * previews, so the original files aren't needed. Returns how many were updated.
 */
export async function embedMissing(
  library: Library,
  model: ModelClient,
  {
    signal,
    onProgress,
  }: { signal: AbortSignal; onProgress: (done: number, total: number) => void },
): Promise<number> {
  const pending = library.all.filter((record) => record.embedding === null);
  if (pending.length === 0 || !model.isReady) {
    return 0;
  }

  let updated = 0;
  for (const [index, record] of pending.entries()) {
    if (signal.aborted) {
      break;
    }
    onProgress(index, pending.length);
    try {
      const embedding = await model.embedImage(record.previewDataUrl);
      await library.update({ ...record, embedding, embeddingModel: MODEL.embeddingVersion });
      updated += 1;
    } catch (error) {
      if (error instanceof ModelResetError || error instanceof StorageFullError) {
        break;
      }
      console.warn(`Couldn’t update ${record.name} for smart search:`, error);
    }
  }
  return updated;
}
