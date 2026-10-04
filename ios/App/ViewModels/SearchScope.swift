import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
  case all
  case photos
  case videos
  case screenshots
  case favorites

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all:
      return "All"
    case .photos:
      return "Photos"
    case .videos:
      return "Videos"
    case .screenshots:
      return "Screenshots"
    case .favorites:
      return "Favorites"
    }
  }

  var queryHint: String {
    switch self {
    case .all:
      return ""
    case .photos:
      return "photos"
    case .videos:
      return "videos"
    case .screenshots:
      return "screenshots"
    case .favorites:
      return "favorite"
    }
  }
}
