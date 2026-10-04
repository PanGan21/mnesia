import Foundation
import Testing
@testable import MnesiaCore

@Suite("SearchDateFilter")
struct SearchDateFilterTests {
  let calendar = Fixtures.utcCalendar
  let now = Fixtures.date("2026-03-10T08:30:00Z")

  func matches(_ filter: SearchDateFilter, _ date: String) -> Bool {
    filter.matches(Fixtures.date(date), calendar: calendar, now: now)
  }

  @Test func today() {
    #expect(matches(.today, "2026-03-10T00:00:00Z"))
    #expect(matches(.today, "2026-03-10T23:59:59Z"))
    #expect(!matches(.today, "2026-03-09T23:59:59Z"))
  }

  @Test func yesterday() {
    #expect(matches(.yesterday, "2026-03-09T00:00:00Z"))
    #expect(!matches(.yesterday, "2026-03-10T00:00:00Z"))
    #expect(!matches(.yesterday, "2026-03-08T23:59:59Z"))
  }

  @Test func yesterdayAcrossYearBoundary() {
    let newYear = Fixtures.date("2026-01-01T10:00:00Z")
    #expect(SearchDateFilter.yesterday.matches(Fixtures.date("2025-12-31T12:00:00Z"), calendar: calendar, now: newYear))
  }

  @Test func thisYearAndLastYear() {
    #expect(matches(.thisYear, "2026-01-01T00:00:00Z"))
    #expect(!matches(.thisYear, "2025-12-31T23:59:59Z"))
    #expect(matches(.lastYear, "2025-06-01T00:00:00Z"))
    #expect(!matches(.lastYear, "2024-12-31T00:00:00Z"))
  }

  @Test func lastDays() {
    #expect(matches(.lastDays(7), "2026-03-04T09:00:00Z"))
    #expect(!matches(.lastDays(7), "2026-03-03T08:00:00Z"))
    #expect(!matches(.lastDays(7), "2026-03-11T08:00:00Z"), "future dates are outside the window")
  }

  @Test func monthMatchesAnyYear() {
    #expect(matches(.month(3), "2019-03-31T12:00:00Z"))
    #expect(!matches(.month(3), "2026-04-01T00:00:00Z"))
  }

  @Test func seasonsWrapAroundTheYear() {
    #expect(matches(.season(.winter), "2025-12-25T00:00:00Z"))
    #expect(matches(.season(.winter), "2026-02-10T00:00:00Z"))
    #expect(matches(.season(.autumn), "2025-10-10T00:00:00Z"))
    #expect(!matches(.season(.summer), "2025-09-01T00:00:00Z"))
  }

  @Test func chipLabelsAreEnglish() {
    #expect(SearchDateFilter.month(11).chipLabel == "November")
    #expect(SearchDateFilter.season(.autumn).chipLabel == "Autumn")
    #expect(SearchDateFilter.lastDays(30).chipLabel == "Last 30 days")
  }
}
