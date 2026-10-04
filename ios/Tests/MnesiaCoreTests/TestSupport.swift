import Foundation
@testable import MnesiaCore

enum Fixtures {
  /// Gregorian calendar pinned to UTC so date-filter tests do not depend on the host time zone.
  static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  static func date(_ iso8601: String) -> Date {
    guard let date = ISO8601DateFormatter().date(from: iso8601) else {
      preconditionFailure("Invalid fixture date \(iso8601)")
    }
    return date
  }

  static func record(
    id: String,
    title: String = "IMG_0001.HEIC",
    mediaKind: AssetMediaKind = .photo,
    createdAt: String = "2025-08-14T18:15:00Z",
    isFavorite: Bool = false,
    tags: [String] = [],
    recognizedText: [String] = [],
    notes: [String] = [],
    location: String? = nil,
    assetVersion: String = "v1"
  ) -> IndexedAssetRecord {
    IndexedAssetRecord(
      id: id,
      title: title,
      mediaKind: mediaKind,
      createdAt: date(createdAt),
      pixelWidth: 1200,
      pixelHeight: 900,
      isFavorite: isFavorite,
      tags: tags,
      recognizedText: recognizedText,
      notes: notes,
      locationDisplayName: location,
      lastIndexedAt: date("2025-12-01T00:00:00Z"),
      assetVersion: assetVersion
    )
  }

  static func descriptor(
    id: String,
    title: String? = nil,
    mediaKind: AssetMediaKind = .photo,
    createdAt: String = "2025-08-14T18:15:00Z",
    isFavorite: Bool = false,
    hasLocation: Bool = false,
    version: String = "v1"
  ) -> LibraryAssetDescriptor {
    LibraryAssetDescriptor(
      id: id,
      title: title ?? "\(id).HEIC",
      mediaKind: mediaKind,
      createdAt: date(createdAt),
      pixelWidth: 4032,
      pixelHeight: 3024,
      isFavorite: isFavorite,
      hasLocation: hasLocation,
      assetVersion: version
    )
  }
}
