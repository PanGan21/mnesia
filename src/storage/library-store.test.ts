import "fake-indexeddb/auto";
import { IDBFactory } from "fake-indexeddb";
import { beforeEach, describe, expect, it } from "vitest";
import { MODEL } from "../config";
import { makeRecord } from "../test/fixtures";
import { LibraryStore, normalizeStoredRecord } from "./library-store";

describe("LibraryStore", () => {
  let store: LibraryStore;
  beforeEach(() => {
    store = new LibraryStore(new IDBFactory());
  });

  it("round-trips records, including embeddings and files", async () => {
    const record = makeRecord({
      embedding: Float32Array.from([0.5, -0.25]),
      embeddingModel: MODEL.embeddingVersion,
      fileBlob: new Blob(["pixels"], { type: "image/jpeg" }),
    });
    await store.put(record);

    const [loaded] = await store.getAll();
    expect(loaded?.id).toBe(record.id);
    expect(Array.from(loaded?.embedding ?? [])).toEqual([0.5, -0.25]);
    expect(loaded?.fileBlob).toBeInstanceOf(Blob);
  });

  it("clears everything", async () => {
    await store.putMany([makeRecord(), makeRecord()]);
    await store.clear();
    expect(await store.getAll()).toEqual([]);
  });

  it("skips malformed records instead of failing the load", async () => {
    const factory = new IDBFactory();
    const raw = new LibraryStore(factory);
    await raw.put(makeRecord());
    const database = await new Promise<IDBDatabase>((resolve) => {
      const request = factory.open("mnesia-local-library", 1);
      request.onsuccess = () => resolve(request.result);
    });
    await new Promise<void>((resolve) => {
      const transaction = database.transaction("records", "readwrite");
      transaction.objectStore("records").put({ id: "broken" });
      transaction.oncomplete = () => resolve();
    });
    database.close();

    expect(await raw.getAll()).toHaveLength(1);
  });
});

describe("normalizeStoredRecord", () => {
  const legacy = {
    id: "a",
    name: "Dogs at the park.jpg",
    mediaKind: "image",
    previewDataUrl: "data:image/jpeg;base64,AAAA",
    size: 10,
    lastModified: 1_700_000_000_000,
    embedding: [0.1, 0.2],
    searchTokens: ["stale"],
  };

  it("keeps embeddings made by the current model", () => {
    const record = normalizeStoredRecord({ ...legacy, embeddingModel: MODEL.embeddingVersion });
    expect(record?.embedding).toBeInstanceOf(Float32Array);
    expect(record?.embeddingModel).toBe(MODEL.embeddingVersion);
  });

  it("drops embeddings from other models so they're recomputed", () => {
    expect(normalizeStoredRecord(legacy)?.embedding).toBeNull();
    expect(
      normalizeStoredRecord({ ...legacy, embeddingModel: "older-model" })?.embeddingModel,
    ).toBeNull();
  });

  it("upgrades records saved by earlier versions", () => {
    const record = normalizeStoredRecord(legacy);
    expect(record?.fingerprint).toBe("Dogs at the park.jpg|10|1700000000000");
    expect(record?.searchTokens).toContain("dog");
    expect(record?.fileBlob).toBeNull();
  });

  it("rejects records that can't be shown safely", () => {
    expect(normalizeStoredRecord(null)).toBeNull();
    expect(normalizeStoredRecord({ ...legacy, mediaKind: "audio" })).toBeNull();
    expect(normalizeStoredRecord({ ...legacy, previewDataUrl: "javascript:alert(1)" })).toBeNull();
    expect(
      normalizeStoredRecord({ ...legacy, previewDataUrl: "https://example.com/x.jpg" }),
    ).toBeNull();
  });

  it("treats empty or invalid embeddings as missing", () => {
    const current = { ...legacy, embeddingModel: MODEL.embeddingVersion };
    expect(normalizeStoredRecord({ ...current, embedding: [] })?.embedding).toBeNull();
    expect(normalizeStoredRecord({ ...current, embedding: ["x"] })?.embedding).toBeNull();
  });
});
