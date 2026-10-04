import Foundation

public enum Season: String, Codable, CaseIterable, Sendable {
  case winter
  case spring
  case summer
  case autumn

  public var displayName: String {
    rawValue.capitalized
  }

  public static func from(month: Int) -> Season {
    switch month {
    case 12, 1, 2:
      return .winter
    case 3, 4, 5:
      return .spring
    case 6, 7, 8:
      return .summer
    default:
      return .autumn
    }
  }
}
