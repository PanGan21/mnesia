import Foundation

public enum AssetMediaKind: String, Codable, CaseIterable, Sendable {
  case photo
  case video
  case screenshot

  public var displayName: String {
    switch self {
    case .photo:
      return "Photo"
    case .video:
      return "Video"
    case .screenshot:
      return "Screenshot"
    }
  }
}
