import type { LibraryStore } from "./storage/library-store";
import type { MediaRecord } from "./types";

/**
 * The library in memory, mirrored to IndexedDB when the person chose to keep it.
 * Records are ordered most recently added first.
 */
export class Library {
  private records: MediaRecord[] = [];
  private readonly fingerprints = new Set<string>();

  constructor(
    private readonly store: LibraryStore,
    private persist: boolean,
  ) {}

  get all(): readonly MediaRecord[] {
    return this.records;
  }

  get size(): number {
    return this.records.length;
  }

  get isPersistent(): boolean {
    return this.persist;
  }

  contains(fingerprint: string): boolean {
    return this.fingerprints.has(fingerprint);
  }

  async load(): Promise<void> {
    const stored = await this.store.getAll();
    this.records = stored.sort((a, b) => b.addedAt - a.addedAt);
    this.fingerprints.clear();
    for (const record of this.records) {
      this.fingerprints.add(record.fingerprint);
    }
  }

  /**
   * Adds a record. It stays available for this session even if saving fails;
   * the error is rethrown so the caller can tell the person.
   */
  async add(record: MediaRecord): Promise<void> {
    this.records.unshift(record);
    this.fingerprints.add(record.fingerprint);
    if (this.persist) {
      await this.store.put(record);
    }
  }

  /** Replaces a record with an updated copy (same id). */
  async update(record: MediaRecord): Promise<void> {
    const index = this.records.findIndex((existing) => existing.id === record.id);
    if (index === -1) {
      return;
    }
    this.records[index] = record;
    if (this.persist) {
      await this.store.put(record);
    }
  }

  /** Turning persistence off removes saved copies; turning it on saves what's here now. */
  async setPersistent(persist: boolean): Promise<void> {
    if (persist === this.persist) {
      return;
    }
    this.persist = persist;
    if (persist) {
      await this.store.putMany(this.records);
    } else {
      await this.store.clear();
    }
  }

  async clear(): Promise<void> {
    this.records = [];
    this.fingerprints.clear();
    await this.store.clear();
  }
}
