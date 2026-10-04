import Foundation

/// Extracts structured filters (media kind, favorites, date hints) from a natural-language query.
/// Every keyword is matched on word boundaries so words that merely contain a keyword
/// ("waterfall", "springfield", "eclipse", "photography") stay free-text terms.
public struct SearchQueryParser: Sendable {
  private static let mediaPatterns: [(pattern: String, kind: AssetMediaKind)] = [
    ("screenshots?", .screenshot),
    ("videos?|clips?|movies?", .video),
    ("photos?|images?|pictures?", .photo),
  ]

  private static let favoritesPattern = "favou?rites?|starred"

  private static let relativeDatePatterns: [(pattern: String, filter: SearchDateFilter)] = [
    ("today", .today),
    ("yesterday", .yesterday),
    ("this year", .thisYear),
    ("last year", .lastYear),
  ]

  private static let lastDaysPattern = "(?:last|past) (\\d{1,4}) days?"
  private static let maxLastDays = 3650

  private static let seasonPatterns: [(pattern: String, season: Season)] = [
    ("winter", .winter),
    ("spring", .spring),
    ("summer", .summer),
    ("autumn|fall", .autumn),
  ]

  private static let monthPatterns: [(pattern: String, month: Int)] = [
    ("january|jan", 1),
    ("february|feb", 2),
    ("march|mar", 3),
    ("april|apr", 4),
    ("may", 5),
    ("june|jun", 6),
    ("july|jul", 7),
    ("august|aug", 8),
    ("september|sept|sep", 9),
    ("october|oct", 10),
    ("november|nov", 11),
    ("december|dec", 12),
  ]

  public init() {}

  public func parse(_ rawText: String) -> SearchQuery {
    var text = rawText.lowercased()
    var mediaKinds = Set<AssetMediaKind>()
    var chips: [String] = []
    var dateFilter: SearchDateFilter?
    var favoritesOnly = false

    for (pattern, kind) in Self.mediaPatterns where text.removeWords(matching: pattern) {
      mediaKinds.insert(kind)
      chips.append(kind.displayName)
    }

    if text.removeWords(matching: Self.favoritesPattern) {
      favoritesOnly = true
      chips.append("Favorites")
    }

    for (pattern, filter) in Self.relativeDatePatterns where text.removeWords(matching: pattern) {
      dateFilter = filter
      break
    }

    if dateFilter == nil, let days = text.removeLastDaysPhrase(pattern: Self.lastDaysPattern) {
      dateFilter = .lastDays(min(max(days, 1), Self.maxLastDays))
    }

    if dateFilter == nil {
      for (pattern, season) in Self.seasonPatterns where text.removeWords(matching: pattern) {
        dateFilter = .season(season)
        break
      }
    }

    if dateFilter == nil {
      for (pattern, month) in Self.monthPatterns where text.removeWords(matching: pattern) {
        dateFilter = .month(month)
        break
      }
    }

    if let dateFilter {
      chips.append(dateFilter.chipLabel)
    }

    let semanticText = text
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let terms = SearchTokenizer.dedupePreservingOrder(SearchTokenizer.tokenize(semanticText))

    return SearchQuery(
      rawText: rawText,
      semanticText: semanticText,
      semanticTerms: terms,
      mediaKinds: mediaKinds,
      dateFilter: dateFilter,
      favoritesOnly: favoritesOnly,
      activeChips: chips
    )
  }
}

private extension String {
  /// Removes every whole-word match of `alternatives` (a regex alternation) and reports whether
  /// anything was removed.
  mutating func removeWords(matching alternatives: String) -> Bool {
    let pattern = "\\b(?:\(alternatives))\\b"
    guard range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
      return false
    }
    self = replacingOccurrences(
      of: pattern,
      with: " ",
      options: [.regularExpression, .caseInsensitive]
    )
    return true
  }

  /// Removes the first "last N days" phrase and returns N.
  mutating func removeLastDaysPhrase(pattern: String) -> Int? {
    guard
      let regex = try? NSRegularExpression(pattern: "\\b\(pattern)\\b", options: [.caseInsensitive]),
      let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
      let fullRange = Range(match.range, in: self),
      let numberRange = Range(match.range(at: 1), in: self),
      let days = Int(self[numberRange])
    else {
      return nil
    }
    replaceSubrange(fullRange, with: " ")
    return days
  }
}
