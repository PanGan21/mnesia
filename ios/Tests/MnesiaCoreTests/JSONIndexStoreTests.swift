import Foundation
import Testing
@testable import MnesiaCore

@Suite("JSONIndexStore")
struct JSONIndexStoreTests {
  let directory: URL
  let fileURL: URL

  init() {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("mnesia-tests-\(UUID().uuidString)", isDirectory: true)
    fileURL = directory.appendingPathComponent("nested/index.json")
  }

  @Test func loadingMissingFileReturnsEmptySnapshot() async throws {
    let store = JSONIndexStore(fileURL: fileURL)
    let snapshot = try await store.load()
    #expect(snapshot.records.isEmpty)
    #expect(snapshot.schemaVersion == MnesiaIndexSnapshot.currentSchemaVersion)
  }

  @Test func roundTripsSnapshotExactly() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONIndexStore(fileURL: fileURL)
    let snapshot = MnesiaIndexSnapshot(
      updatedAt: Fixtures.date("2025-12-01T10:00:00Z"),
      records: [
        Fixtures.record(id: "a", tags: ["sample"], recognizedText: ["Hello"], location: "Location tagged"),
        Fixtures.record(id: "b", mediaKind: .video, isFavorite: true, assetVersion: "v9"),
      ]
    )

    try await store.save(snapshot)
    let loaded = try await store.load()

    #expect(loaded == snapshot)
  }

  @Test func saveOverwritesPreviousSnapshot() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONIndexStore(fileURL: fileURL)
    try await store.save(MnesiaIndexSnapshot(records: [Fixtures.record(id: "old")]))
    try await store.save(MnesiaIndexSnapshot(records: [Fixtures.record(id: "new")]))

    #expect(try await store.load().records.map(\.id) == ["new"])
  }

  @Test func clearRemovesIndexAndIsIdempotent() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONIndexStore(fileURL: fileURL)
    try await store.save(MnesiaIndexSnapshot(records: [Fixtures.record(id: "a")]))

    try await store.clear()
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    try await store.clear()
    #expect(try await store.load().records.isEmpty)
  }

  @Test func corruptFileThrowsCorrupted() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: fileURL)

    let store = JSONIndexStore(fileURL: fileURL)
    await #expect(throws: IndexStoreError.corrupted) {
      try await store.load()
    }
  }

  @Test func structurallyInvalidSnapshotThrowsCorrupted() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(#"{"schemaVersion": 2, "records": "nope"}"#.utf8).write(to: fileURL)

    let store = JSONIndexStore(fileURL: fileURL)
    await #expect(throws: IndexStoreError.corrupted) {
      try await store.load()
    }
  }

  @Test func newerSchemaIsRejected() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(#"{"schemaVersion": 99, "updatedAt": "2025-01-01T00:00:00Z", "records": []}"#.utf8).write(to: fileURL)

    let store = JSONIndexStore(fileURL: fileURL)
    await #expect(throws: IndexStoreError.unsupportedSchemaVersion(99)) {
      try await store.load()
    }
  }

  @Test func olderSchemaStillLoads() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONIndexStore(fileURL: fileURL)
    try await store.save(MnesiaIndexSnapshot(schemaVersion: 1, records: [Fixtures.record(id: "legacy")]))

    let loaded = try await store.load()
    #expect(loaded.schemaVersion == 1)
    #expect(loaded.records.map(\.id) == ["legacy"])
  }

  @Test func excludesIndexDirectoryFromBackup() async throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONIndexStore(fileURL: fileURL)
    try await store.save(MnesiaIndexSnapshot(records: []))

    let values = try fileURL.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
    #expect(values.isExcludedFromBackup == true)
  }
}
