import Foundation

/// Platform-independent description of one library asset, as enumerated by a
/// `LibraryAssetCatalog` (PhotoKit on iOS). Contains metadata only, never pixels.
public struct LibraryAssetDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let title: String
  public let mediaKind: AssetMediaKind
  public let createdAt: Date
  public let duration: TimeInterval?
  public let pixelWidth: Int
  public let pixelHeight: Int
  public let isFavorite: Bool
  public let hasLocation: Bool
  /// Opaque fingerprint that changes whenever the asset content changes.
  public let assetVersion: String

  public init(
    id: String,
    title: String,
    mediaKind: AssetMediaKind,
    createdAt: Date,
    duration: TimeInterval? = nil,
    pixelWidth: Int,
    pixelHeight: Int,
    isFavorite: Bool,
    hasLocation: Bool,
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
    self.hasLocation = hasLocation
    self.assetVersion = assetVersion
  }
}

/// Output of on-device analysis for a single asset.
public struct AssetSemanticAnalysis: Hashable, Sendable {
  public var tags: [String]
  public var recognizedText: [String]
  public var notes: [String]

  public init(tags: [String], recognizedText: [String], notes: [String]) {
    self.tags = tags
    self.recognizedText = recognizedText
    self.notes = notes
  }
}
