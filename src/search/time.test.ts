import { describe, expect, it } from "vitest";
import { matchesTimeFilter, monthKeyOf, seasonOf } from "./time";

const at = (year: number, month: number, day = 15) => new Date(year, month, day, 12).getTime();
const now = new Date(2026, 3, 20, 12); // 20 April 2026

describe("time filters", () => {
  it("maps months to seasons", () => {
    expect(seasonOf(new Date(2025, 11, 1))).toBe("winter");
    expect(seasonOf(new Date(2025, 1, 1))).toBe("winter");
    expect(seasonOf(new Date(2025, 2, 1))).toBe("spring");
    expect(seasonOf(new Date(2025, 6, 1))).toBe("summer");
    expect(seasonOf(new Date(2025, 9, 1))).toBe("autumn");
    expect(monthKeyOf(new Date(2025, 0, 1))).toBe("jan");
  });

  it("matches relative ranges against the given date", () => {
    expect(matchesTimeFilter(at(2026, 3, 1), "30d", now)).toBe(true);
    expect(matchesTimeFilter(at(2026, 1, 1), "30d", now)).toBe(false);
    expect(matchesTimeFilter(at(2026, 0, 1), "this-year", now)).toBe(true);
    expect(matchesTimeFilter(at(2025, 6, 1), "last-year", now)).toBe(true);
    expect(matchesTimeFilter(at(2024, 6, 1), "last-year", now)).toBe(false);
  });

  it("doesn't count future dates as recent", () => {
    expect(matchesTimeFilter(at(2026, 5, 1), "30d", now)).toBe(false);
  });

  it("matches seasons and months in any year", () => {
    expect(matchesTimeFilter(at(2019, 7), "summer", now)).toBe(true);
    expect(matchesTimeFilter(at(2019, 7), "aug", now)).toBe(true);
    expect(matchesTimeFilter(at(2019, 7), "sep", now)).toBe(false);
    expect(matchesTimeFilter(at(2019, 7), "all", now)).toBe(true);
  });
});
