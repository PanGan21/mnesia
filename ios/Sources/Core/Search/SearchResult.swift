import Foundation

public enum SearchMatchField: String, Codable, CaseIterable, Sendable {
  case title
  case tags
  case recognizedText
  case notes
  case date
  case location
  case mediaKind
  case favorite
}

public struct SearchResult: Identifiable, Hashable, Sendable {
  public var id: String { record.id }
  public var record: IndexedAssetRecord
  public var score: Double
  public var matchedTerms: [String]
  public var matchedFields: [SearchMatchField]

  public init(
    record: IndexedAssetRecord,
    score: Double,
    matchedTerms: [String],
    matchedFields: [SearchMatchField]
  ) {
    self.record = record
    self.score = score
    self.matchedTerms = matchedTerms
    self.matchedFields = matchedFields
  }
}
