import Foundation
import Testing
@testable import MnesiaCore

@Suite("LibrarySearchEngine")
struct LibrarySearchEngineTests {
  let engine = LibrarySearchEngine(calendar: Fixtures.utcCalendar)
  let now = Fixtures.date("2025-12-15T12:00:00Z")

  let records: [IndexedAssetRecord] = [
    Fixtures.record(
      id: "dog-1",
      title: "dog park sunset",
      createdAt: "2025-08-14T18:15:00Z",
      tags: ["dog", "park", "sunset"],
      notes: ["outdoors"]
    ),
    Fixtures.record(
      id: "cake-1",
      title: "birthday kitchen",
      createdAt: "2025-11-02T19:40:00Z",
      isFavorite: true,
      tags: ["birthday", "cake", "candles"],
      notes: ["family dinner"]
    ),
    Fixtures.record(
      id: "receipt-1",
      title: "IMG_2001.PNG",
      mediaKind: .screenshot,
      createdAt: "2025-12-14T09:00:00Z",
      recognizedText: ["Total due 42 EUR", "Thanks for shopping"]
    ),
    Fixtures.record(
      id: "clip-1",
      title: "IMG_3001.MOV",
      mediaKind: .video,
      createdAt: "2024-07-04T21:00:00Z",
      tags: ["fireworks", "sky"],
      location: "Location tagged"
    ),
  ]

  func ids(_ query: String, sort: SearchSortMode = .bestMatch) -> [String] {
    engine.search(records: records, rawQuery: query, sortMode: sort, now: now).map(\.record.id)
  }

  @Test func ranksDirectLexicalMatchFirst() {
    #expect(ids("dog park sunset").first == "dog-1")
  }

  @Test func filtersByMonthAndFavorites() {
    #expect(ids("favorite photos in november") == ["cake-1"])
  }

  @Test func emptyQueryReturnsEverythingNewestFirst() {
    #expect(ids("") == ["receipt-1", "cake-1", "dog-1", "clip-1"])
  }

  @Test func termsWithoutMatchesReturnNothing() {
    #expect(ids("giraffe").isEmpty)
  }

  @Test func filterOnlyQueriesDoNotRequireTermMatches() {
    #expect(ids("videos") == ["clip-1"])
    #expect(ids("screenshots") == ["receipt-1"])
  }

  @Test func matchesPluralQueryAgainstSingularTag() {
    #expect(ids("dogs") == ["dog-1"])
    #expect(ids("candle") == ["cake-1"])
  }

  @Test func reportsSurfaceTermsAndMatchedFields() throws {
    let result = try #require(engine.search(records: records, rawQuery: "dogs outdoors", now: now).first)
    #expect(result.record.id == "dog-1")
    #expect(result.matchedTerms == ["dogs", "outdoors"])
    #expect(result.matchedFields == [.notes, .tags, .title])
  }

  @Test func matchesRecognizedTextAndLocation() {
    #expect(ids("total due") == ["receipt-1"])
    #expect(ids("location") == ["clip-1"])
  }

  @Test func titleOutweighsTagsAndTagsOutweighNotes() {
    let fieldRecords = [
      Fixtures.record(id: "note", createdAt: "2025-01-03T00:00:00Z", notes: ["lake"]),
      Fixtures.record(id: "tag", createdAt: "2025-01-02T00:00:00Z", tags: ["lake"]),
      Fixtures.record(id: "title", title: "lake", createdAt: "2025-01-01T00:00:00Z"),
    ]
    let results = engine.search(records: fieldRecords, rawQuery: "lake", now: now)
    #expect(results.map(\.record.id) == ["title", "tag", "note"])
  }

  @Test func rewardsCoverageOfMultipleTerms() {
    let coverageRecords = [
      Fixtures.record(id: "one", createdAt: "2025-01-02T00:00:00Z", tags: ["beach"]),
      Fixtures.record(id: "both", createdAt: "2025-01-01T00:00:00Z", tags: ["beach", "sunset"]),
    ]
    let results = engine.search(records: coverageRecords, rawQuery: "beach sunset", now: now)
    #expect(results.map(\.record.id) == ["both", "one"])
    #expect(results[0].score > results[1].score)
  }

  @Test func sortModesAreDeterministic() {
    let sortRecords = [
      Fixtures.record(id: "b", title: "Beta", createdAt: "2025-01-01T00:00:00Z", tags: ["x"]),
      Fixtures.record(id: "a", title: "alpha", createdAt: "2025-01-01T00:00:00Z", tags: ["x"]),
      Fixtures.record(id: "c", title: "Gamma 10", createdAt: "2025-03-01T00:00:00Z", tags: ["x"]),
      Fixtures.record(id: "d", title: "Gamma 9", createdAt: "2025-02-01T00:00:00Z", tags: ["x"]),
    ]
    func sorted(_ mode: SearchSortMode) -> [String] {
      engine.search(records: sortRecords, rawQuery: "x", sortMode: mode, now: now).map(\.record.id)
    }

    #expect(sorted(.bestMatch) == ["c", "d", "a", "b"])
    #expect(sorted(.newestFirst) == ["c", "d", "a", "b"])
    #expect(sorted(.oldestFirst) == ["a", "b", "d", "c"])
    #expect(sorted(.title) == ["a", "b", "d", "c"])
  }

  @Test func relativeDateFiltersUseInjectedNow() {
    #expect(ids("yesterday") == ["receipt-1"])
    #expect(ids("last 60 days") == ["receipt-1", "cake-1"])
    #expect(ids("this year") == ["receipt-1", "cake-1", "dog-1"])
    #expect(ids("last year") == ["clip-1"])
    #expect(ids("fireworks summer") == ["clip-1"])
  }

  @Test func preparedIndexMatchesConvenienceSearch() {
    let index = LibrarySearchIndex(records: records)
    let prepared = engine.search(index: index, rawQuery: "birthday cake", now: now)
    let direct = engine.search(records: records, rawQuery: "birthday cake", now: now)
    #expect(prepared == direct)
    #expect(index.count == records.count)
  }
}
