import Foundation

public struct IndexedAssetRecord: Identifiable, Codable, Hashable, Sendable {
  public let id: String
  public var title: String
  public var mediaKind: AssetMediaKind
  public var createdAt: Date
  public var duration: TimeInterval?
  public var pixelWidth: Int
  public var pixelHeight: Int
  public var isFavorite: Bool
  public var tags: [String]
  public var recognizedText: [String]
  public var notes: [String]
  public var locationDisplayName: String?
  public var lastIndexedAt: Date
  /// Opaque fingerprint of the asset content at analysis time. When the library reports the same
  /// version again, the record's analysis is reused instead of re-running Vision.
  public var assetVersion: String

  public init(
    id: String,
    title: String,
    mediaKind: AssetMediaKind,
    createdAt: Date,
    duration: TimeInterval? = nil,
    pixelWidth: Int,
    pixelHeight: Int,
    isFavorite: Bool,
    tags: [String],
    recognizedText: [String],
    notes: [String],
    locationDisplayName: String? = nil,
    lastIndexedAt: Date,
    assetVersion: String
  ) {
    self.id = id
    self.title = title
    self.mediaKind = mediaKind
    self.createdAt = createdAt
    self.duration = duration
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
    self.isFavorite = isFavorite
    self.tags = tags
    self.recognizedText = recognizedText
    self.notes = notes
    self.locationDisplayName = locationDisplayName
    self.lastIndexedAt = lastIndexedAt
    self.assetVersion = assetVersion
  }
}

extension IndexedAssetRecord {
  /// Placeholder shown/searched for assets that carry GPS data. mnesia never reverse-geocodes
  /// (that would require network access), so the actual place name is unknown.
  static let locationTaggedLabel = "Location tagged"

  /// Builds a fresh record from library metadata plus on-device analysis output.
  public init(
    descriptor: LibraryAssetDescriptor,
    analysis: AssetSemanticAnalysis,
    indexedAt: Date
  ) {
    self.init(
      id: descriptor.id,
      title: descriptor.title,
      mediaKind: descriptor.mediaKind,
      createdAt: descriptor.createdAt,
      duration: descriptor.duration,
      pixelWidth: descriptor.pixelWidth,
      pixelHeight: descriptor.pixelHeight,
      isFavorite: descriptor.isFavorite,
      tags: Self.normalizedList(analysis.tags),
      recognizedText: Self.normalizedList(analysis.recognizedText),
      notes: Self.normalizedList(analysis.notes),
      locationDisplayName: descriptor.hasLocation ? Self.locationTaggedLabel : nil,
      lastIndexedAt: indexedAt,
      assetVersion: descriptor.assetVersion
    )
  }

  /// Returns a copy whose library metadata (title, date, favorite, ...) reflects `descriptor`
  /// while keeping the stored analysis and `assetVersion` untouched.
  public func refreshingMetadata(from descriptor: LibraryAssetDescriptor) -> IndexedAssetRecord {
    var copy = self
    copy.title = descriptor.title
    copy.mediaKind = descriptor.mediaKind
    copy.createdAt = descriptor.createdAt
    copy.duration = descriptor.duration
    copy.pixelWidth = descriptor.pixelWidth
    copy.pixelHeight = descriptor.pixelHeight
    copy.isFavorite = descriptor.isFavorite
    copy.locationDisplayName = descriptor.hasLocation ? Self.locationTaggedLabel : nil
    return copy
  }

  private static func normalizedList(_ values: [String]) -> [String] {
    let trimmed = values
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return SearchTokenizer.dedupePreservingOrder(trimmed)
  }
}
