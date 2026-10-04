import Foundation

public struct MnesiaIndexSnapshot: Codable, Hashable, Sendable {
  /// Bump whenever the meaning of stored record fields changes (e.g. how tags or notes are
  /// derived). Snapshots with an older schema are still readable, but the indexer re-analyzes
  /// every asset instead of reusing their records.
  ///
  /// - 1: tags/notes mixed Vision output with derived media-kind/favorite/location words.
  /// - 2: tags/notes contain Vision output only; metadata lives in dedicated fields.
  public static let currentSchemaVersion = 2

  public var schemaVersion: Int
  public var updatedAt: Date
  public var records: [IndexedAssetRecord]

  public init(
    schemaVersion: Int = MnesiaIndexSnapshot.currentSchemaVersion,
    updatedAt: Date = .now,
    records: [IndexedAssetRecord]
  ) {
    self.schemaVersion = schemaVersion
    self.updatedAt = updatedAt
    self.records = records
  }

  public static let empty = MnesiaIndexSnapshot(updatedAt: .distantPast, records: [])
}
