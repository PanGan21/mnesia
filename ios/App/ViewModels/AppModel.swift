import Foundation
import MnesiaCore
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
  enum IndexState: Equatable {
    case idle
    case indexing(IndexingProgress)
    /// `summary` is nil when the state was restored from disk rather than produced by a run.
    case completed(date: Date, summary: IndexingSummary?)
    /// The run was cancelled; work done so far was kept.
    case cancelled(IndexingSummary)
    case failed(String)
  }

  /// Longest edge, in pixels, requested for the full-screen photo preview.
  static let previewMaxPixelSize: CGFloat = 2048

  @Published private(set) var authorizationState: PhotoAuthorizationState = .notDetermined
  @Published private(set) var indexedRecords: [IndexedAssetRecord] = []
  @Published private(set) var libraryResults: [SearchResult] = []
  @Published private(set) var searchResults: [SearchResult] = []
  @Published var searchText = "" {
    didSet { refreshSearch() }
  }
  @Published var selectedScope: SearchScope = .all {
    didSet { refreshSearch() }
  }
  @Published var sortMode: SearchSortMode = .bestMatch {
    didSet { refreshSearch() }
  }
  @Published private(set) var indexState: IndexState = .idle
  @Published var selectedResult: SearchResult?
  @Published private(set) var lastIndexedAt: Date?

  private let photoLibrary: any PhotoLibraryAccessing
  private let indexStore: JSONIndexStore
  private let indexer: LibraryIndexer
  private let searchEngine = LibrarySearchEngine()
  private var snapshot: MnesiaIndexSnapshot = .empty
  private var searchIndex = LibrarySearchIndex(records: [])
  private var indexingTask: Task<Void, Never>?
  private var hasLoaded = false

  init(
    photoLibrary: any PhotoLibraryAccessing,
    indexStore: JSONIndexStore,
    indexer: LibraryIndexer
  ) {
    self.photoLibrary = photoLibrary
    self.indexStore = indexStore
    self.indexer = indexer
  }

  var resultCountLabel: String {
    searchResults.count == 1 ? "1 match" : "\(searchResults.count) matches"
  }

  var libraryCountLabel: String {
    "\(indexedRecords.count) indexed"
  }

  var isIndexing: Bool {
    indexingTask != nil
  }

  // MARK: Lifecycle

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    hasLoaded = true

    refreshAuthorization()

    do {
      apply(try await indexStore.load())
      indexState = snapshot.records.isEmpty ? .idle : .completed(date: snapshot.updatedAt, summary: nil)
    } catch IndexStoreError.corrupted {
      await resetDamagedIndex()
    } catch IndexStoreError.unsupportedSchemaVersion {
      indexState = .failed("The saved index was created by a newer version of mnesia. Update the app or rebuild the index.")
    } catch {
      indexState = .failed("Unable to load the saved local index: \(error.localizedDescription)")
    }
  }

  /// Re-reads the authorization status, e.g. after returning from the Settings app.
  func refreshAuthorization() {
    authorizationState = photoLibrary.authorizationState()
  }

  func requestPhotoAccess() async {
    authorizationState = await photoLibrary.requestAuthorization()

    if authorizationState.canBrowseLibrary && indexedRecords.isEmpty {
      startIndexing()
    }
  }

  // MARK: Indexing

  /// Starts an index update in the background. No-op while a run is already in progress.
  func startIndexing(mode: IndexingMode = .incremental) {
    guard authorizationState.canBrowseLibrary, indexingTask == nil else {
      return
    }

    indexState = .indexing(IndexingProgress(processedCount: 0, totalCount: 0))
    let existing = snapshot
    indexingTask = Task { [weak self] in
      await self?.runIndexing(existing: existing, mode: mode)
    }
  }

  /// Stops the current run. Assets analyzed so far are kept and saved.
  func cancelIndexing() {
    indexingTask?.cancel()
  }

  func clearLocalIndex() async {
    if let task = indexingTask {
      task.cancel()
      await task.value
    }

    do {
      try await indexStore.clear()
      apply(.empty)
      selectedResult = nil
      indexState = .idle
    } catch {
      indexState = .failed("Unable to clear the local index: \(error.localizedDescription)")
    }
  }

  private func runIndexing(existing: MnesiaIndexSnapshot, mode: IndexingMode) async {
    defer { indexingTask = nil }

    let result: IndexingResult
    do {
      result = try await indexer.updateIndex(existing: existing, mode: mode) { [weak self] progress in
        await self?.reportProgress(progress)
      }
    } catch is CancellationError {
      indexState = snapshot.records.isEmpty ? .idle : .completed(date: snapshot.updatedAt, summary: nil)
      return
    } catch {
      indexState = .failed("Indexing failed: \(error.localizedDescription)")
      return
    }

    apply(result.snapshot)

    do {
      try await indexStore.save(result.snapshot)
      indexState = result.summary.wasCancelled
        ? .cancelled(result.summary)
        : .completed(date: result.snapshot.updatedAt, summary: result.summary)
    } catch {
      indexState = .failed("The index was updated but could not be saved: \(error.localizedDescription)")
    }
  }

  private func reportProgress(_ progress: IndexingProgress) {
    // Ignore late progress callbacks once the run has finished.
    guard indexingTask != nil else { return }
    indexState = .indexing(progress)
  }

  private func resetDamagedIndex() async {
    do {
      try await indexStore.clear()
      indexState = .failed("The saved index was damaged and has been reset. Update the index to rebuild it.")
    } catch {
      indexState = .failed("The saved index is damaged and could not be reset: \(error.localizedDescription)")
    }
  }

  // MARK: Search

  func refreshSearch() {
    searchResults = searchEngine.search(
      index: searchIndex,
      rawQuery: effectiveQuery,
      sortMode: sortMode
    )
  }

  private var effectiveQuery: String {
    [searchText, selectedScope.queryHint]
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " ")
  }

  private func apply(_ snapshot: MnesiaIndexSnapshot) {
    self.snapshot = snapshot
    indexedRecords = snapshot.records.sorted { $0.createdAt > $1.createdAt }
    libraryResults = indexedRecords.map { record in
      SearchResult(record: record, score: 1, matchedTerms: [], matchedFields: [])
    }
    searchIndex = LibrarySearchIndex(records: indexedRecords)
    lastIndexedAt = snapshot.records.isEmpty ? nil : snapshot.updatedAt
    if let selected = selectedResult, !snapshot.records.contains(where: { $0.id == selected.id }) {
      selectedResult = nil
    }
    refreshSearch()
  }

  // MARK: Media loading

  /// Returns nil when no local thumbnail exists (e.g. iCloud-only) or the request was cancelled;
  /// the tile then shows a placeholder, which is the intended UX for both cases.
  func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
    try? await photoLibrary.loadThumbnail(for: localIdentifier, targetSize: targetSize)
  }

  func loadDisplayAsset(for localIdentifier: String) async throws -> DisplayAssetPayload {
    try await photoLibrary.loadDisplayAsset(
      for: localIdentifier,
      maximumImageSize: CGSize(width: Self.previewMaxPixelSize, height: Self.previewMaxPixelSize)
    )
  }
}
