import Foundation

/// Records paired with their pre-computed matching keys, so a search does not re-tokenize the
/// whole library on every keystroke. Build it once whenever the record set changes.
public struct LibrarySearchIndex: Sendable {
  struct Entry: Sendable {
    let record: IndexedAssetRecord
    let titleKeys: Set<String>
    let tagKeys: Set<String>
    let textKeys: Set<String>
    let noteKeys: Set<String>
    let locationKeys: Set<String>

    init(record: IndexedAssetRecord) {
      self.record = record
      titleKeys = SearchTokenizer.matchKeys(record.title)
      tagKeys = SearchTokenizer.matchKeys(record.tags.joined(separator: " "))
      textKeys = SearchTokenizer.matchKeys(record.recognizedText.joined(separator: " "))
      noteKeys = SearchTokenizer.matchKeys(record.notes.joined(separator: " "))
      locationKeys = SearchTokenizer.matchKeys(record.locationDisplayName ?? "")
    }
  }

  let entries: [Entry]

  public init(records: [IndexedAssetRecord]) {
    entries = records.map(Entry.init(record:))
  }

  public var count: Int { entries.count }
}
