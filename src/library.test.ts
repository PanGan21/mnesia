import { IDBFactory } from "fake-indexeddb";
import { describe, expect, it } from "vitest";
import { Library } from "./library";
import { LibraryStore } from "./storage/library-store";
import { makeRecord } from "./test/fixtures";

describe("Library", () => {
  it("saves records only while persistence is on", async () => {
    const store = new LibraryStore(new IDBFactory());
    const library = new Library(store, false);
    await library.add(makeRecord());
    expect(await store.getAll()).toHaveLength(0);

    await library.setPersistent(true);
    expect(await store.getAll()).toHaveLength(1);

    await library.add(makeRecord());
    expect(await store.getAll()).toHaveLength(2);
  });

  it("removes saved copies when persistence is turned off but keeps the session", async () => {
    const store = new LibraryStore(new IDBFactory());
    const library = new Library(store, true);
    await library.add(makeRecord());

    await library.setPersistent(false);
    expect(await store.getAll()).toHaveLength(0);
    expect(library.size).toBe(1);
  });

  it("updates a record in memory and storage", async () => {
    const store = new LibraryStore(new IDBFactory());
    const library = new Library(store, true);
    const record = makeRecord();
    await library.add(record);

    await library.update({ ...record, name: "renamed.jpg" });
    expect(library.all[0]?.name).toBe("renamed.jpg");
    expect((await store.getAll())[0]?.name).toBe("renamed.jpg");
  });

  it("tracks fingerprints for duplicate detection and restores newest first", async () => {
    const store = new LibraryStore(new IDBFactory());
    const older = makeRecord({ addedAt: 1 });
    const newer = makeRecord({ addedAt: 2 });
    await store.putMany([older, newer]);

    const library = new Library(store, true);
    await library.load();
    expect(library.all.map((record) => record.id)).toEqual([newer.id, older.id]);
    expect(library.contains(older.fingerprint)).toBe(true);

    await library.clear();
    expect(library.contains(older.fingerprint)).toBe(false);
    expect(await store.getAll()).toHaveLength(0);
  });
});
