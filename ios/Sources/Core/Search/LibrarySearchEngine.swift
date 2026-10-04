import Foundation

public struct LibrarySearchEngine: Sendable {
  enum Weight {
    static let title = 5.0
    static let tags = 3.5
    static let recognizedText = 3.0
    static let location = 2.5
    static let notes = 2.0
    static let coverage = 2.5
    static let screenshot = 0.25
    static let favorite = 0.15
  }

  private let calendar: Calendar
  private let parser = SearchQueryParser()

  public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
    self.calendar = calendar
  }

  public func parse(_ rawQuery: String) -> SearchQuery {
    parser.parse(rawQuery)
  }

  /// Convenience for one-off searches. Prefer building a `LibrarySearchIndex` once and reusing it.
  public func search(
    records: [IndexedAssetRecord],
    rawQuery: String,
    sortMode: SearchSortMode = .bestMatch,
    now: Date = .now
  ) -> [SearchResult] {
    search(index: LibrarySearchIndex(records: records), query: parse(rawQuery), sortMode: sortMode, now: now)
  }

  public func search(
    index: LibrarySearchIndex,
    rawQuery: String,
    sortMode: SearchSortMode = .bestMatch,
    now: Date = .now
  ) -> [SearchResult] {
    search(index: index, query: parse(rawQuery), sortMode: sortMode, now: now)
  }

  /// Filters by the query's structured constraints, scores free-text terms against the indexed
  /// fields and sorts the matches. `now` anchors relative date filters ("today", "last 30 days").
  public func search(
    index: LibrarySearchIndex,
    query: SearchQuery,
    sortMode: SearchSortMode = .bestMatch,
    now: Date = .now
  ) -> [SearchResult] {
    let terms = query.semanticTerms.map { (term: $0, key: SearchTokenizer.normalize($0)) }

    let results: [SearchResult] = index.entries.compactMap { entry in
      let record = entry.record
      if !query.mediaKinds.isEmpty && !query.mediaKinds.contains(record.mediaKind) {
        return nil
      }

      if query.favoritesOnly && !record.isFavorite {
        return nil
      }

      if let dateFilter = query.dateFilter, !dateFilter.matches(record.createdAt, calendar: calendar, now: now) {
        return nil
      }

      if terms.isEmpty {
        return SearchResult(record: record, score: 1, matchedTerms: [], matchedFields: [])
      }

      return evaluate(entry, terms: terms)
    }

    return sort(results, using: sortMode)
  }

  private func evaluate(
    _ entry: LibrarySearchIndex.Entry,
    terms: [(term: String, key: String)]
  ) -> SearchResult? {
    let fields: [(keys: Set<String>, weight: Double, field: SearchMatchField)] = [
      (entry.titleKeys, Weight.title, .title),
      (entry.tagKeys, Weight.tags, .tags),
      (entry.textKeys, Weight.recognizedText, .recognizedText),
      (entry.noteKeys, Weight.notes, .notes),
      (entry.locationKeys, Weight.location, .location),
    ]

    var score = 0.0
    var matchedTerms: [String] = []
    var matchedFields = Set<SearchMatchField>()

    for (term, key) in terms {
      var matched = false
      for field in fields where field.keys.contains(key) {
        score += field.weight
        matchedFields.insert(field.field)
        matched = true
      }
      if matched {
        matchedTerms.append(term)
      }
    }

    guard !matchedTerms.isEmpty else {
      return nil
    }

    if terms.count > 1 {
      score += Double(matchedTerms.count) / Double(terms.count) * Weight.coverage
    }

    if entry.record.mediaKind == .screenshot {
      score += Weight.screenshot
    }

    if entry.record.isFavorite {
      score += Weight.favorite
    }

    return SearchResult(
      record: entry.record,
      score: score,
      matchedTerms: matchedTerms,
      matchedFields: matchedFields.sorted { $0.rawValue < $1.rawValue }
    )
  }

  /// Sorts deterministically: every mode falls back to newest-first, then to the record id.
  private func sort(
    _ results: [SearchResult],
    using sortMode: SearchSortMode
  ) -> [SearchResult] {
    func newestFirst(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
      if lhs.record.createdAt != rhs.record.createdAt {
        return lhs.record.createdAt > rhs.record.createdAt
      }
      return lhs.record.id < rhs.record.id
    }

    switch sortMode {
    case .bestMatch:
      return results.sorted {
        $0.score != $1.score ? $0.score > $1.score : newestFirst($0, $1)
      }
    case .newestFirst:
      return results.sorted(by: newestFirst)
    case .oldestFirst:
      return results.sorted {
        if $0.record.createdAt != $1.record.createdAt {
          return $0.record.createdAt < $1.record.createdAt
        }
        return $0.record.id < $1.record.id
      }
    case .title:
      return results.sorted {
        let order = $0.record.title.localizedStandardCompare($1.record.title)
        return order == .orderedSame ? newestFirst($0, $1) : order == .orderedAscending
      }
    }
  }
}
