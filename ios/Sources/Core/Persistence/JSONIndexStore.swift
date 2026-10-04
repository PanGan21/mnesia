import Foundation

public enum IndexStoreError: Error, Equatable, Sendable {
  /// The index file exists but cannot be decoded. It is derived data, so the caller should
  /// `clear()` it and rebuild.
  case corrupted
  /// The index was written by a newer app version with an unknown schema.
  case unsupportedSchemaVersion(Int)
}

/// Persists the index as a single JSON file.
///
/// - Writes are atomic (temp file + rename), so a crash never leaves a half-written index.
/// - On iOS the file uses `completeUntilFirstUserAuthentication` protection: encrypted at rest
///   until the first unlock after boot, while still allowing future background refreshes
///   (`complete` would make the file unreadable whenever the device is locked).
/// - The containing directory is excluded from device backups by default. The index is fully
///   derivable from the on-device library, contains sensitive derived data (OCR text), and is
///   keyed by PhotoKit local identifiers that are not stable across devices, so restoring it
///   elsewhere has no value while copying it off-device widens its exposure.
public actor JSONIndexStore {
  private let fileURL: URL
  private let excludesFromBackup: Bool
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(fileURL: URL, excludesFromBackup: Bool = true) {
    self.fileURL = fileURL
    self.excludesFromBackup = excludesFromBackup

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  /// Loads the saved snapshot, or `.empty` when nothing has been saved yet.
  public func load() throws -> MnesiaIndexSnapshot {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
      return .empty
    }

    let header: SchemaHeader
    do {
      header = try decoder.decode(SchemaHeader.self, from: data)
    } catch {
      throw IndexStoreError.corrupted
    }

    guard header.schemaVersion <= MnesiaIndexSnapshot.currentSchemaVersion else {
      throw IndexStoreError.unsupportedSchemaVersion(header.schemaVersion)
    }

    do {
      return try decoder.decode(MnesiaIndexSnapshot.self, from: data)
    } catch {
      throw IndexStoreError.corrupted
    }
  }

  public func save(_ snapshot: MnesiaIndexSnapshot) throws {
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if excludesFromBackup {
      try excludeFromBackup(directory)
    }

    let data = try encoder.encode(snapshot)
    try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  /// Deletes the saved index. Succeeds when there is nothing to delete.
  public func clear() throws {
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch let error as CocoaError where error.code == .fileNoSuchFile {
      return
    }
  }

  private func excludeFromBackup(_ directory: URL) throws {
    var directory = directory
    if (try? directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) == true {
      return
    }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
  }

  private struct SchemaHeader: Decodable {
    let schemaVersion: Int
  }
}
