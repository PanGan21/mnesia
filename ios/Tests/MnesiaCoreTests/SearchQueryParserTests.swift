import Testing
@testable import MnesiaCore

@Suite("SearchQueryParser")
struct SearchQueryParserTests {
  let parser = SearchQueryParser()

  @Test func extractsMediaKindsFavoritesAndMonth() {
    let query = parser.parse("favorite videos from april with birthday cake")

    #expect(query.mediaKinds == [.video])
    #expect(query.favoritesOnly)
    #expect(query.dateFilter == .month(4))
    #expect(query.semanticTerms == ["birthday", "cake"])
    #expect(query.activeChips == ["Video", "Favorites", "April"])
  }

  @Test func preservesPlainSemanticTerms() {
    let query = parser.parse("dog running in the park at sunset")

    #expect(query.semanticTerms == ["dog", "running", "park", "sunset"])
    #expect(query.dateFilter == nil)
    #expect(query.mediaKinds.isEmpty)
    #expect(!query.favoritesOnly)
    #expect(query.activeChips.isEmpty)
  }

  // MARK: Word-boundary regressions

  @Test func waterfallIsNotAutumn() {
    let query = parser.parse("waterfall")
    #expect(query.semanticTerms == ["waterfall"])
    #expect(query.dateFilter == nil)
  }

  @Test func springfieldIsNotSpring() {
    let query = parser.parse("springfield trip")
    #expect(query.semanticTerms == ["springfield", "trip"])
    #expect(query.dateFilter == nil)
  }

  @Test func eclipseIsNotAVideoClip() {
    let query = parser.parse("eclipse")
    #expect(query.semanticTerms == ["eclipse"])
    #expect(query.mediaKinds.isEmpty)
  }

  @Test func photographyIsNotAPhotoFilter() {
    let query = parser.parse("photography")
    #expect(query.semanticTerms == ["photography"])
    #expect(query.mediaKinds.isEmpty)
  }

  @Test(arguments: ["todays", "birthday yesterdays", "unfavorited", "screenshotting", "mayor", "decor", "marathon"])
  func keywordsInsideWordsAreNotFilters(_ text: String) {
    let query = parser.parse(text)
    #expect(query.dateFilter == nil)
    #expect(query.mediaKinds.isEmpty)
    #expect(!query.favoritesOnly)
  }

  // MARK: Filters

  @Test(arguments: [
    ("screenshot", AssetMediaKind.screenshot),
    ("screenshots", .screenshot),
    ("clips", .video),
    ("movie", .video),
    ("pictures", .photo),
    ("image", .photo),
  ])
  func recognizesMediaKinds(_ text: String, _ kind: AssetMediaKind) {
    let query = parser.parse(text)
    #expect(query.mediaKinds == [kind])
    #expect(query.semanticTerms.isEmpty)
  }

  @Test func combinesMultipleMediaKinds() {
    let query = parser.parse("photos and videos of the beach")
    #expect(query.mediaKinds == [.photo, .video])
    #expect(query.semanticTerms == ["beach"])
  }

  @Test(arguments: ["favorite", "favorites", "favourite", "starred"])
  func recognizesFavorites(_ text: String) {
    let query = parser.parse("\(text) sunsets")
    #expect(query.favoritesOnly)
    #expect(query.semanticTerms == ["sunsets"])
  }

  @Test(arguments: [
    ("pets today", SearchDateFilter.today),
    ("pets yesterday", .yesterday),
    ("pets this year", .thisYear),
    ("pets last year", .lastYear),
    ("pets last 30 days", .lastDays(30)),
    ("pets in the past 7 days", .lastDays(7)),
    ("pets last 1 day", .lastDays(1)),
  ])
  func recognizesRelativeDates(_ text: String, _ filter: SearchDateFilter) {
    let query = parser.parse(text)
    #expect(query.dateFilter == filter)
    #expect(query.semanticTerms == ["pets"])
  }

  @Test func clampsAbsurdDayRanges() {
    #expect(parser.parse("last 0 days").dateFilter == .lastDays(1))
    #expect(parser.parse("last 9999 days").dateFilter == .lastDays(3650))
  }

  @Test(arguments: [
    ("winter", Season.winter),
    ("spring", .spring),
    ("summer", .summer),
    ("autumn", .autumn),
    ("fall", .autumn),
  ])
  func recognizesSeasons(_ season: String, _ expected: Season) {
    let query = parser.parse("hiking last \(season)")
    #expect(query.dateFilter == .season(expected))
    #expect(query.semanticTerms == ["hiking"])
  }

  @Test(arguments: [("jan", 1), ("feb", 2), ("march", 3), ("may", 5), ("sept", 9), ("sep", 9), ("december", 12)])
  func recognizesMonths(_ month: String, _ expected: Int) {
    let query = parser.parse("snow \(month)")
    #expect(query.dateFilter == .month(expected))
    #expect(query.semanticTerms == ["snow"])
  }

  @Test func relativeDateTakesPrecedenceOverSeasonAndMonth() {
    let query = parser.parse("summer dresses today in june")
    #expect(query.dateFilter == .today)
    #expect(query.semanticTerms == ["summer", "dresses", "june"])
  }

  @Test func isCaseInsensitive() {
    let query = parser.parse("Favorite VIDEOS From August")
    #expect(query.favoritesOnly)
    #expect(query.mediaKinds == [.video])
    #expect(query.dateFilter == .month(8))
    #expect(query.semanticTerms.isEmpty)
    #expect(query.rawText == "Favorite VIDEOS From August")
  }

  @Test func emptyAndWhitespaceQueriesAreEmpty() {
    #expect(parser.parse("").isEmpty)
    #expect(parser.parse("   \n ").isEmpty)
    #expect(parser.parse("the of and").isEmpty)
  }

  @Test func deduplicatesTerms() {
    #expect(parser.parse("cat cat Cat").semanticTerms == ["cat"])
  }
}
