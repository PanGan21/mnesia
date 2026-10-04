import { MODEL, STORAGE } from "../config";
import { buildSearchTokens } from "../search/ranking";
import type { MediaRecord } from "../types";

/** Thrown when the browser refuses to store more data for this site. */
export class StorageFullError extends Error {
  constructor() {
    super("This browser has run out of storage space for mnesia.");
    this.name = "StorageFullError";
  }
}

export function fingerprintOf(file: { name: string; size: number; lastModified: number }): string {
  return `${file.name}|${file.size}|${file.lastModified}`;
}

function isQuotaError(error: unknown): boolean {
  return error instanceof DOMException && error.name === "QuotaExceededError";
}

function requestToPromise<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("IndexedDB request failed."));
  });
}

function transactionDone(transaction: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => {
      reject(
        isQuotaError(transaction.error)
          ? new StorageFullError()
          : (transaction.error ?? new Error("IndexedDB transaction failed.")),
      );
    };
    transaction.onabort = () => {
      reject(
        isQuotaError(transaction.error)
          ? new StorageFullError()
          : (transaction.error ?? new Error("IndexedDB transaction was aborted.")),
      );
    };
  });
}

/** Persists the library in IndexedDB. One connection is opened lazily and reused. */
export class LibraryStore {
  private connection: Promise<IDBDatabase> | null = null;

  constructor(private readonly factory: IDBFactory = indexedDB) {}

  private database(): Promise<IDBDatabase> {
    this.connection ??= new Promise((resolve, reject) => {
      const request = this.factory.open(STORAGE.databaseName, STORAGE.databaseVersion);

      request.onupgradeneeded = () => {
        const database = request.result;
        if (!database.objectStoreNames.contains(STORAGE.recordStore)) {
          database.createObjectStore(STORAGE.recordStore, { keyPath: "id" });
        }
      };
      request.onsuccess = () => {
        const database = request.result;
        // Let a newer version of the app in another tab upgrade the schema.
        database.onversionchange = () => {
          database.close();
          this.connection = null;
        };
        resolve(database);
      };
      request.onerror = () => {
        this.connection = null;
        reject(request.error ?? new Error("Couldn't open the local library."));
      };
      request.onblocked = () => {
        this.connection = null;
        reject(new Error("Close other mnesia tabs, then reload this page."));
      };
    });
    return this.connection;
  }

  /** Loads every record, migrating older shapes and dropping anything malformed. */
  async getAll(): Promise<MediaRecord[]> {
    const database = await this.database();
    const transaction = database.transaction(STORAGE.recordStore, "readonly");
    const raw = await requestToPromise(transaction.objectStore(STORAGE.recordStore).getAll());
    return raw.map(normalizeStoredRecord).filter((record) => record !== null);
  }

  async putMany(records: readonly MediaRecord[]): Promise<void> {
    if (records.length === 0) {
      return;
    }
    const database = await this.database();
    const transaction = database.transaction(STORAGE.recordStore, "readwrite");
    const store = transaction.objectStore(STORAGE.recordStore);
    for (const record of records) {
      store.put(record);
    }
    await transactionDone(transaction);
  }

  put(record: MediaRecord): Promise<void> {
    return this.putMany([record]);
  }

  async clear(): Promise<void> {
    const database = await this.database();
    const transaction = database.transaction(STORAGE.recordStore, "readwrite");
    transaction.objectStore(STORAGE.recordStore).clear();
    await transactionDone(transaction);
  }
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function toEmbedding(value: unknown): Float32Array | null {
  if (value instanceof Float32Array) {
    return value.length > 0 ? value : null;
  }
  // Records saved before embeddings were stored as typed arrays.
  if (Array.isArray(value) && value.length > 0 && value.every(isFiniteNumber)) {
    return Float32Array.from(value);
  }
  return null;
}

/**
 * Validates a stored record and upgrades older shapes. Returns null for
 * anything that can't be shown safely, rather than failing the whole load.
 */
export function normalizeStoredRecord(value: unknown): MediaRecord | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }
  const raw = value as Record<string, unknown>;

  const { id, name, mediaKind, previewDataUrl } = raw;
  if (
    typeof id !== "string" ||
    typeof name !== "string" ||
    (mediaKind !== "image" && mediaKind !== "video") ||
    typeof previewDataUrl !== "string" ||
    !previewDataUrl.startsWith("data:image/")
  ) {
    return null;
  }

  const size = isFiniteNumber(raw.size) ? raw.size : 0;
  const lastModified = isFiniteNumber(raw.lastModified) ? raw.lastModified : Date.now();

  return {
    id,
    name,
    mediaKind,
    mimeType: typeof raw.mimeType === "string" ? raw.mimeType : "",
    size,
    lastModified,
    addedAt: isFiniteNumber(raw.addedAt) ? raw.addedAt : lastModified,
    fingerprint:
      typeof raw.fingerprint === "string"
        ? raw.fingerprint
        : fingerprintOf({ name, size, lastModified }),
    previewDataUrl,
    width: isFiniteNumber(raw.width) && raw.width > 0 ? raw.width : 4,
    height: isFiniteNumber(raw.height) && raw.height > 0 ? raw.height : 3,
    duration: isFiniteNumber(raw.duration) ? raw.duration : null,
    fileBlob: raw.fileBlob instanceof Blob ? raw.fileBlob : null,
    // Embeddings from a different model aren't comparable; they're recomputed.
    ...(raw.embeddingModel === MODEL.embeddingVersion
      ? { embedding: toEmbedding(raw.embedding), embeddingModel: MODEL.embeddingVersion }
      : { embedding: null, embeddingModel: null }),
    // Always rebuilt, so tokenizer improvements apply to existing libraries.
    searchTokens: buildSearchTokens(name, lastModified, mediaKind),
  };
}
