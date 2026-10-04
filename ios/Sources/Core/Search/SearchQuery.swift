import Foundation

public enum SearchDateFilter: Equatable, Codable, Sendable {
  case today
  case yesterday
  case thisYear
  case lastYear
  case month(Int)
  case season(Season)
  case lastDays(Int)

  /// English month names, matching the rest of the (English-only) UI regardless of device locale.
  private static let monthSymbols: [String] = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar.monthSymbols
  }()

  public var chipLabel: String {
    switch self {
    case .today:
      return "Today"
    case .yesterday:
      return "Yesterday"
    case .thisYear:
      return "This year"
    case .lastYear:
      return "Last year"
    case .month(let value):
      return Self.monthSymbols[max(0, min(11, value - 1))]
    case .season(let season):
      return season.displayName
    case .lastDays(let days):
      return days == 1 ? "Last day" : "Last \(days) days"
    }
  }

  /// Returns whether `date` satisfies the filter, with relative filters evaluated against `now`.
  public func matches(_ date: Date, calendar: Calendar, now: Date) -> Bool {
    switch self {
    case .today:
      return calendar.isDate(date, inSameDayAs: now)
    case .yesterday:
      guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
        return false
      }
      return calendar.isDate(date, inSameDayAs: yesterday)
    case .thisYear:
      return calendar.component(.year, from: date) == calendar.component(.year, from: now)
    case .lastYear:
      return calendar.component(.year, from: date) == calendar.component(.year, from: now) - 1
    case .month(let month):
      return calendar.component(.month, from: date) == month
    case .season(let season):
      return Season.from(month: calendar.component(.month, from: date)) == season
    case .lastDays(let days):
      guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else {
        return false
      }
      return date >= cutoff && date <= now
    }
  }
}

public struct SearchQuery: Equatable, Sendable {
  public var rawText: String
  public var semanticText: String
  /// Free-text terms as typed (lowercased, stop words removed), in order of appearance.
  public var semanticTerms: [String]
  public var mediaKinds: Set<AssetMediaKind>
  public var dateFilter: SearchDateFilter?
  public var favoritesOnly: Bool
  public var activeChips: [String]

  public init(
    rawText: String,
    semanticText: String,
    semanticTerms: [String],
    mediaKinds: Set<AssetMediaKind> = [],
    dateFilter: SearchDateFilter? = nil,
    favoritesOnly: Bool = false,
    activeChips: [String] = []
  ) {
    self.rawText = rawText
    self.semanticText = semanticText
    self.semanticTerms = semanticTerms
    self.mediaKinds = mediaKinds
    self.dateFilter = dateFilter
    self.favoritesOnly = favoritesOnly
    self.activeChips = activeChips
  }

  public var isEmpty: Bool {
    semanticTerms.isEmpty && mediaKinds.isEmpty && dateFilter == nil && !favoritesOnly
  }
}
