import Foundation

public enum SearchSortMode: String, Codable, CaseIterable, Sendable {
  case bestMatch
  case newestFirst
  case oldestFirst
  case title

  public var displayName: String {
    switch self {
    case .bestMatch:
      return "Best Match"
    case .newestFirst:
      return "Newest"
    case .oldestFirst:
      return "Oldest"
    case .title:
      return "Title"
    }
  }
}
