import { IDBFactory } from "fake-indexeddb";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { embedMissing, importFiles } from "./importer";
import { Library } from "./library";
import { UnreadableMediaError } from "./media/previews";
import { ModelResetError, type ModelClient } from "./model/model-client";
import { LibraryStore, StorageFullError } from "./storage/library-store";
import { makeRecord } from "./test/fixtures";
import { MODEL } from "./config";
import type * as Previews from "./media/previews";

vi.mock("./media/previews", async (importOriginal) => {
  const original = await importOriginal<typeof Previews>();
  return {
    ...original,
    createPreview: vi.fn((file: File) =>
      file.name.startsWith("broken")
        ? Promise.reject(new original.UnreadableMediaError(file.name))
        : Promise.resolve({
            dataUrl: "data:image/jpeg;base64,AAAA",
            width: 4,
            height: 3,
            duration: null,
          }),
    ),
  };
});

const file = (name: string, type = "image/jpeg") =>
  new File(["x"], name, { type, lastModified: 1 });

function readyModel(overrides: Partial<ModelClient> = {}): ModelClient {
  return {
    isReady: true,
    isUnavailable: false,
    ensureReady: () => Promise.resolve(true),
    embedImage: () => Promise.resolve(Float32Array.from([1, 0])),
    subscribe: () => () => undefined,
    ...overrides,
  } as unknown as ModelClient;
}

describe("importFiles", () => {
  let library: Library;
  const options = () => ({
    signal: new AbortController().signal,
    onProgress: vi.fn(),
    onAdded: vi.fn(),
  });

  beforeEach(() => {
    library = new Library(new LibraryStore(new IDBFactory()), true);
  });

  it("adds media with embeddings and reports what it skipped", async () => {
    const summary = await importFiles(
      [file("a.jpg"), file("a.jpg"), file("notes.txt", "text/plain"), file("broken.jpg")],
      library,
      readyModel(),
      options(),
    );

    expect(summary).toEqual({
      added: 1,
      addedVideos: 0,
      duplicates: 1,
      unreadable: 1,
      ignored: 1,
      stopped: null,
    });
    expect(library.all[0]?.embedding).toEqual(Float32Array.from([1, 0]));
  });

  it("skips files already in the library", async () => {
    await importFiles([file("a.jpg")], library, readyModel(), options());
    const summary = await importFiles([file("a.jpg")], library, readyModel(), options());
    expect(summary.duplicates).toBe(1);
    expect(library.size).toBe(1);
  });

  it("imports without embeddings when the model is unavailable", async () => {
    const summary = await importFiles(
      [file("a.jpg")],
      library,
      readyModel({ isReady: false, isUnavailable: true }),
      options(),
    );
    expect(summary.added).toBe(1);
    expect(library.all[0]?.embedding).toBeNull();
  });

  it("stops when canceled", async () => {
    const controller = new AbortController();
    const summary = await importFiles(
      [file("a.jpg"), file("b.jpg")],
      library,
      readyModel({
        embedImage: () => {
          controller.abort();
          return Promise.reject(new ModelResetError());
        },
      }),
      { ...options(), signal: controller.signal },
    );
    expect(summary).toMatchObject({ added: 0, stopped: "canceled" });
  });

  it("stops when storage is full but keeps the item for this session", async () => {
    vi.spyOn(library, "add").mockRejectedValueOnce(new StorageFullError());
    const summary = await importFiles(
      [file("a.jpg"), file("b.jpg")],
      library,
      readyModel(),
      options(),
    );
    expect(summary).toMatchObject({ added: 1, stopped: "storage-full" });
  });

  it("exposes unreadable files as a typed error", () => {
    expect(new UnreadableMediaError("x.heic").message).toContain("x.heic");
  });
});

describe("embedMissing", () => {
  it("embeds items that smart search hasn't processed yet", async () => {
    const library = new Library(new LibraryStore(new IDBFactory()), true);
    const done = makeRecord({
      embedding: Float32Array.from([0, 1]),
      embeddingModel: MODEL.embeddingVersion,
    });
    const pending = makeRecord();
    await library.add(done);
    await library.add(pending);
    const progress = vi.fn();

    const updated = await embedMissing(library, readyModel(), {
      signal: new AbortController().signal,
      onProgress: progress,
    });

    expect(updated).toBe(1);
    expect(progress).toHaveBeenCalledWith(0, 1);
    const refreshed = library.all.find((record) => record.id === pending.id);
    expect(refreshed?.embedding).toEqual(Float32Array.from([1, 0]));
    expect(refreshed?.embeddingModel).toBe(MODEL.embeddingVersion);
  });

  it("does nothing until smart search is ready", async () => {
    const library = new Library(new LibraryStore(new IDBFactory()), false);
    await library.add(makeRecord());
    const updated = await embedMissing(library, readyModel({ isReady: false }), {
      signal: new AbortController().signal,
      onProgress: vi.fn(),
    });
    expect(updated).toBe(0);
  });
});
