import Foundation

/// Enumerates the assets that should be present in the index.
public protocol LibraryAssetCatalog: Sendable {
  func fetchAssetDescriptors() async throws -> [LibraryAssetDescriptor]
}

/// Produces semantic analysis for one asset. Implementations must stay fully on-device.
public protocol LibraryAssetAnalyzing: Sendable {
  func analyze(_ descriptor: LibraryAssetDescriptor) async throws -> AssetSemanticAnalysis
}

/// Expected, non-fatal reasons an analyzer can give for not producing a result.
public enum AssetAnalysisError: Error, Equatable, Sendable {
  /// The asset's pixels are not on this device (e.g. iCloud-only) and network access is disabled.
  case notAvailableLocally
  /// The asset disappeared between enumeration and analysis.
  case assetMissing
}

public enum IndexingMode: Sendable {
  /// Reuse records whose `assetVersion` is unchanged; analyze only new or changed assets.
  case incremental
  /// Re-analyze every asset.
  case full
}

public struct IndexingProgress: Equatable, Sendable {
  /// Assets handled so far among those that need analysis (reused assets are not counted).
  public var processedCount: Int
  public var totalCount: Int
  public var reusedCount: Int
  public var skippedCount: Int
  public var failedCount: Int

  public init(
    processedCount: Int,
    totalCount: Int,
    reusedCount: Int = 0,
    skippedCount: Int = 0,
    failedCount: Int = 0
  ) {
    self.processedCount = processedCount
    self.totalCount = totalCount
    self.reusedCount = reusedCount
    self.skippedCount = skippedCount
    self.failedCount = failedCount
  }

  public var fractionCompleted: Double {
    guard totalCount > 0 else { return 0 }
    return min(1, Double(processedCount) / Double(totalCount))
  }
}

public struct IndexingSummary: Equatable, Sendable {
  /// Assets reported by the catalog.
  public var totalAssetCount: Int = 0
  /// Unchanged assets whose previous record was reused without re-analysis.
  public var reusedCount: Int = 0
  /// New or changed assets analyzed in this run.
  public var analyzedCount: Int = 0
  /// Assets that could not be analyzed because they are not stored on the device.
  public var skippedCount: Int = 0
  /// Assets whose analysis failed for an unexpected reason.
  public var failedCount: Int = 0
  /// Previously indexed assets that are no longer in the library.
  public var removedCount: Int = 0
  /// Assets left unprocessed because the run was cancelled.
  public var pendingCount: Int = 0
  public var wasCancelled = false

  public init() {}

  /// Number of library assets that are not backed by an up-to-date analysis.
  public var unindexedCount: Int {
    skippedCount + failedCount + pendingCount
  }
}

public struct IndexingResult: Sendable {
  public var snapshot: MnesiaIndexSnapshot
  public var summary: IndexingSummary

  public init(snapshot: MnesiaIndexSnapshot, summary: IndexingSummary) {
    self.snapshot = snapshot
    self.summary = summary
  }
}

/// Builds or incrementally updates the local index.
///
/// Records are reused when their `assetVersion` matches the catalog, removed assets are dropped,
/// and only new or changed assets are analyzed. When analysis of a changed asset is not possible,
/// its previous record (if any) is kept, still carrying the old version so it is retried next run.
///
/// Cancellation is cooperative: when the surrounding task is cancelled during analysis, the
/// indexer stops and returns a consistent partial result (`summary.wasCancelled == true`) so work
/// already done can be persisted. Cancellation before enumeration finishes throws
/// `CancellationError`.
public actor LibraryIndexer {
  private let catalog: any LibraryAssetCatalog
  private let analyzer: any LibraryAssetAnalyzing
  private let now: @Sendable () -> Date

  public init(
    catalog: any LibraryAssetCatalog,
    analyzer: any LibraryAssetAnalyzing,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.catalog = catalog
    self.analyzer = analyzer
    self.now = now
  }

  public func updateIndex(
    existing: MnesiaIndexSnapshot,
    mode: IndexingMode = .incremental,
    progress: @escaping @Sendable (IndexingProgress) async -> Void = { _ in }
  ) async throws -> IndexingResult {
    let fetched = try await catalog.fetchAssetDescriptors()
    try Task.checkCancellation()

    var seenIDs = Set<String>()
    let descriptors = fetched.filter { seenIDs.insert($0.id).inserted }

    let canReuse = mode == .incremental
      && existing.schemaVersion == MnesiaIndexSnapshot.currentSchemaVersion
    let previous: [String: IndexedAssetRecord] = Dictionary(
      existing.records.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    var summary = IndexingSummary()
    summary.totalAssetCount = descriptors.count
    summary.removedCount = previous.keys.filter { !seenIDs.contains($0) }.count

    var records: [IndexedAssetRecord] = []
    records.reserveCapacity(descriptors.count)
    var pending: [LibraryAssetDescriptor] = []

    for descriptor in descriptors {
      if canReuse, let record = previous[descriptor.id], record.assetVersion == descriptor.assetVersion {
        records.append(record.refreshingMetadata(from: descriptor))
        summary.reusedCount += 1
      } else {
        pending.append(descriptor)
      }
    }

    // Keeps the previous (stale) record for an asset that could not be re-analyzed. Its old
    // `assetVersion` guarantees a retry on the next run. Records from an incompatible schema
    // are never carried over.
    func keepPreviousRecord(for descriptor: LibraryAssetDescriptor) {
      guard canReuse, let record = previous[descriptor.id] else { return }
      records.append(record.refreshingMetadata(from: descriptor))
    }

    func currentProgress(processed: Int) -> IndexingProgress {
      IndexingProgress(
        processedCount: processed,
        totalCount: pending.count,
        reusedCount: summary.reusedCount,
        skippedCount: summary.skippedCount,
        failedCount: summary.failedCount
      )
    }

    var processed = 0
    while processed < pending.count {
      if Task.isCancelled {
        summary.wasCancelled = true
        break
      }

      await progress(currentProgress(processed: processed))
      let descriptor = pending[processed]

      do {
        let analysis = try await analyzer.analyze(descriptor)
        records.append(IndexedAssetRecord(descriptor: descriptor, analysis: analysis, indexedAt: now()))
        summary.analyzedCount += 1
      } catch is CancellationError {
        summary.wasCancelled = true
        break
      } catch AssetAnalysisError.notAvailableLocally {
        summary.skippedCount += 1
        keepPreviousRecord(for: descriptor)
      } catch AssetAnalysisError.assetMissing {
        summary.removedCount += 1
      } catch {
        summary.failedCount += 1
        keepPreviousRecord(for: descriptor)
      }

      processed += 1
    }

    if summary.wasCancelled {
      let unprocessed = pending[processed...]
      summary.pendingCount = unprocessed.count
      for descriptor in unprocessed {
        keepPreviousRecord(for: descriptor)
      }
    } else {
      await progress(currentProgress(processed: pending.count))
    }

    records.sort {
      if $0.createdAt != $1.createdAt {
        return $0.createdAt > $1.createdAt
      }
      return $0.id < $1.id
    }

    return IndexingResult(
      snapshot: MnesiaIndexSnapshot(updatedAt: now(), records: records),
      summary: summary
    )
  }
}
