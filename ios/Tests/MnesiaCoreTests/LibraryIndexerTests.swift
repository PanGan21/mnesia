import Foundation
import Testing
@testable import MnesiaCore

struct StubCatalog: LibraryAssetCatalog {
  var descriptors: [LibraryAssetDescriptor]

  func fetchAssetDescriptors() async throws -> [LibraryAssetDescriptor] {
    descriptors
  }
}

/// Records analyzed ids and returns canned results or errors per asset id.
final class StubAnalyzer: LibraryAssetAnalyzing {
  private let failures: [String: any Error]
  private let analyzed = Locked<[String]>([])
  private let onAnalyze: @Sendable (String) -> Void

  init(failures: [String: any Error] = [:], onAnalyze: @escaping @Sendable (String) -> Void = { _ in }) {
    self.failures = failures
    self.onAnalyze = onAnalyze
  }

  var analyzedIDs: [String] {
    analyzed.withLock { $0 }
  }

  func analyze(_ descriptor: LibraryAssetDescriptor) async throws -> AssetSemanticAnalysis {
    analyzed.withLock { $0.append(descriptor.id) }
    onAnalyze(descriptor.id)
    if let error = failures[descriptor.id] {
      throw error
    }
    return AssetSemanticAnalysis(
      tags: ["tag-\(descriptor.id)", " ", "tag-\(descriptor.id)"],
      recognizedText: ["text \(descriptor.id)"],
      notes: ["person"]
    )
  }
}

struct UnexpectedFailure: Error {}

final class ProgressLog: Sendable {
  private let events = Locked<[IndexingProgress]>([])

  var all: [IndexingProgress] { events.withLock { $0 } }

  func append(_ progress: IndexingProgress) {
    events.withLock { $0.append(progress) }
  }
}

@Suite("LibraryIndexer")
struct LibraryIndexerTests {
  let indexedAt = Fixtures.date("2026-01-01T00:00:00Z")

  func makeIndexer(_ descriptors: [LibraryAssetDescriptor], _ analyzer: StubAnalyzer) -> LibraryIndexer {
    let indexedAt = indexedAt
    return LibraryIndexer(
      catalog: StubCatalog(descriptors: descriptors),
      analyzer: analyzer,
      now: { indexedAt }
    )
  }

  @Test func firstRunAnalyzesEverythingAndBuildsRecords() async throws {
    let analyzer = StubAnalyzer()
    let descriptors = [
      Fixtures.descriptor(id: "a", createdAt: "2025-01-01T00:00:00Z", isFavorite: true, hasLocation: true),
      Fixtures.descriptor(id: "b", mediaKind: .video, createdAt: "2025-02-01T00:00:00Z"),
    ]

    let result = try await makeIndexer(descriptors, analyzer).updateIndex(existing: .empty)

    #expect(Set(analyzer.analyzedIDs) == ["a", "b"])
    #expect(result.summary.analyzedCount == 2)
    #expect(result.summary.reusedCount == 0)
    #expect(result.snapshot.records.map(\.id) == ["b", "a"], "newest first")
    #expect(result.snapshot.updatedAt == indexedAt)
    #expect(result.snapshot.schemaVersion == MnesiaIndexSnapshot.currentSchemaVersion)

    let a = try #require(result.snapshot.records.first { $0.id == "a" })
    #expect(a.tags == ["tag-a"], "blank and duplicate tags are dropped")
    #expect(a.recognizedText == ["text a"])
    #expect(a.notes == ["person"])
    #expect(a.isFavorite)
    #expect(a.locationDisplayName == "Location tagged")
    #expect(a.assetVersion == "v1")
    #expect(a.lastIndexedAt == indexedAt)
  }

  @Test func incrementalRunReusesUnchangedAnalyzesChangedAndDropsRemoved() async throws {
    let existing = MnesiaIndexSnapshot(records: [
      Fixtures.record(id: "same", tags: ["old-same"], assetVersion: "v1"),
      Fixtures.record(id: "changed", tags: ["old-changed"], assetVersion: "v1"),
      Fixtures.record(id: "gone", assetVersion: "v1"),
    ])
    let descriptors = [
      Fixtures.descriptor(id: "same", isFavorite: true, version: "v1"),
      Fixtures.descriptor(id: "changed", version: "v2"),
      Fixtures.descriptor(id: "new", version: "v1"),
    ]
    let analyzer = StubAnalyzer()

    let result = try await makeIndexer(descriptors, analyzer).updateIndex(existing: existing)

    #expect(Set(analyzer.analyzedIDs) == ["changed", "new"])
    #expect(result.summary.reusedCount == 1)
    #expect(result.summary.analyzedCount == 2)
    #expect(result.summary.removedCount == 1)
    #expect(Set(result.snapshot.records.map(\.id)) == ["same", "changed", "new"])

    let same = try #require(result.snapshot.records.first { $0.id == "same" })
    #expect(same.tags == ["old-same"], "analysis is reused")
    #expect(same.isFavorite, "library metadata is refreshed on reuse")

    let changed = try #require(result.snapshot.records.first { $0.id == "changed" })
    #expect(changed.tags == ["tag-changed"])
    #expect(changed.assetVersion == "v2")
  }

  @Test func fullModeReanalyzesEverything() async throws {
    let existing = MnesiaIndexSnapshot(records: [Fixtures.record(id: "a", assetVersion: "v1")])
    let analyzer = StubAnalyzer()

    let result = try await makeIndexer([Fixtures.descriptor(id: "a")], analyzer)
      .updateIndex(existing: existing, mode: .full)

    #expect(analyzer.analyzedIDs == ["a"])
    #expect(result.summary.reusedCount == 0)
  }

  @Test func olderSchemaForcesReanalysis() async throws {
    let existing = MnesiaIndexSnapshot(schemaVersion: 1, records: [Fixtures.record(id: "a", assetVersion: "v1")])
    let analyzer = StubAnalyzer(failures: ["a": AssetAnalysisError.notAvailableLocally])

    let result = try await makeIndexer([Fixtures.descriptor(id: "a")], analyzer).updateIndex(existing: existing)

    #expect(analyzer.analyzedIDs == ["a"])
    #expect(result.snapshot.records.isEmpty, "legacy records are never carried over")
  }

  @Test func countsSkippedFailedAndMissingAssets() async throws {
    let analyzer = StubAnalyzer(failures: [
      "cloud": AssetAnalysisError.notAvailableLocally,
      "broken": UnexpectedFailure(),
      "deleted": AssetAnalysisError.assetMissing,
    ])
    let descriptors = ["ok", "cloud", "broken", "deleted"].map { Fixtures.descriptor(id: $0) }

    let result = try await makeIndexer(descriptors, analyzer).updateIndex(existing: .empty)

    #expect(result.summary.totalAssetCount == 4)
    #expect(result.summary.analyzedCount == 1)
    #expect(result.summary.skippedCount == 1)
    #expect(result.summary.failedCount == 1)
    #expect(result.summary.removedCount == 1)
    #expect(result.summary.unindexedCount == 2)
    #expect(result.snapshot.records.map(\.id) == ["ok"])
  }

  @Test func keepsStaleRecordWhenChangedAssetCannotBeAnalyzed() async throws {
    let existing = MnesiaIndexSnapshot(records: [Fixtures.record(id: "cloud", tags: ["old"], assetVersion: "v1")])
    let analyzer = StubAnalyzer(failures: ["cloud": AssetAnalysisError.notAvailableLocally])

    let result = try await makeIndexer([Fixtures.descriptor(id: "cloud", version: "v2")], analyzer)
      .updateIndex(existing: existing)

    let record = try #require(result.snapshot.records.first)
    #expect(record.tags == ["old"])
    #expect(record.assetVersion == "v1", "old version keeps the asset eligible for a retry")
    #expect(result.summary.skippedCount == 1)
  }

  @Test func ignoresDuplicateDescriptors() async throws {
    let analyzer = StubAnalyzer()
    let result = try await makeIndexer([Fixtures.descriptor(id: "a"), Fixtures.descriptor(id: "a")], analyzer)
      .updateIndex(existing: .empty)

    #expect(analyzer.analyzedIDs == ["a"])
    #expect(result.snapshot.records.count == 1)
  }

  @Test func reportsProgressForAnalyzedAssetsOnly() async throws {
    let existing = MnesiaIndexSnapshot(records: [Fixtures.record(id: "same")])
    let descriptors = ["same", "x", "y"].map { Fixtures.descriptor(id: $0) }
    let log = ProgressLog()

    _ = try await makeIndexer(descriptors, StubAnalyzer()).updateIndex(existing: existing) { progress in
      log.append(progress)
    }

    #expect(log.all.map(\.processedCount) == [0, 1, 2])
    #expect(log.all.allSatisfy { $0.totalCount == 2 && $0.reusedCount == 1 })
    #expect(log.all.last?.fractionCompleted == 1)
  }

  @Test func cancellationReturnsConsistentPartialResult() async throws {
    let existing = MnesiaIndexSnapshot(records: [Fixtures.record(id: "d", tags: ["old-d"], assetVersion: "v0")])
    let descriptors = ["a", "b", "c", "d"].map { Fixtures.descriptor(id: $0) }
    let gate = AsyncGate()
    let analyzer = StubAnalyzer { id in
      if id == "b" { gate.open() }
    }
    let indexer = makeIndexer(descriptors, analyzer)

    let task = Task {
      try await indexer.updateIndex(existing: existing) { _ in
        // Yield so the test can cancel between assets.
        await Task.yield()
      }
    }
    await gate.wait()
    task.cancel()
    let result = try await task.value

    #expect(result.summary.wasCancelled)
    #expect(result.summary.analyzedCount + result.summary.pendingCount == 4)
    #expect(result.summary.pendingCount >= 1)
    let ids = Set(result.snapshot.records.map(\.id))
    #expect(ids.contains("a"))
    #expect(ids.contains("d"), "unprocessed assets keep their previous record")
    #expect(analyzer.analyzedIDs.count == result.summary.analyzedCount)
  }

  @Test func cancellationBeforeEnumerationThrows() async {
    let indexer = makeIndexer([Fixtures.descriptor(id: "a")], StubAnalyzer())
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await indexer.updateIndex(existing: .empty)
    }
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }
}

/// One-shot signal that lets a test await an event raised from another task.
final class AsyncGate: Sendable {
  private let state = Locked<(isOpen: Bool, waiters: [CheckedContinuation<Void, Never>])>((false, []))

  func open() {
    let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
      state.isOpen = true
      defer { state.waiters = [] }
      return state.waiters
    }
    waiters.forEach { $0.resume() }
  }

  func wait() async {
    await withCheckedContinuation { continuation in
      let resumeNow = state.withLock { state -> Bool in
        if state.isOpen { return true }
        state.waiters.append(continuation)
        return false
      }
      if resumeNow { continuation.resume() }
    }
  }
}

/// Minimal lock-protected box for test doubles (the package still targets macOS 14, so
/// `Synchronization.Mutex` is unavailable).
final class Locked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&value)
  }
}
