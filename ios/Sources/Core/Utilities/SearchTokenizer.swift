import Foundation

enum SearchTokenizer {
  private static let stopWords: Set<String> = [
    "a",
    "an",
    "and",
    "at",
    "by",
    "for",
    "from",
    "in",
    "last",
    "near",
    "of",
    "on",
    "the",
    "to",
    "with",
  ]

  /// Splits text into lowercase, diacritic-folded word tokens, dropping stop words and
  /// single-character tokens.
  static func tokenize(_ value: String) -> [String] {
    value
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .lowercased()
      .split { !$0.isLetter && !$0.isNumber }
      .map(String.init)
      .filter { $0.count > 1 && !stopWords.contains($0) }
  }

  /// Tokenizes and reduces each token to its matching key (see `normalize`).
  static func matchKeys(_ value: String) -> Set<String> {
    Set(tokenize(value).map(normalize))
  }

  /// Light, deterministic plural folding used to build matching keys. It is applied symmetrically
  /// to query terms and indexed text, so the key only needs to be consistent, not a real word:
  /// "dogs"/"dog" -> "dog", "puppies"/"puppy" -> "puppi", "movies"/"movie" -> "movi",
  /// "beaches"/"beach" -> "beach", "glasses"/"glass" -> "glass".
  /// Tokens containing digits or non-letters, and very short tokens, are returned unchanged.
  static func normalize(_ token: String) -> String {
    guard token.count > 3, token.allSatisfy({ $0.isLetter && $0.isASCII }) else {
      return token
    }

    var key = token
    if key.hasSuffix("ies"), key.count > 4 {
      key = String(key.dropLast(3)) + "i"
    } else if key.hasSuffix("sses") {
      key = String(key.dropLast(2))
    } else if ["ches", "shes", "xes", "zzes"].contains(where: key.hasSuffix) {
      key = String(key.dropLast(2))
    } else if key.hasSuffix("s"), !["ss", "us", "is"].contains(where: key.hasSuffix) {
      key = String(key.dropLast())
    }

    // Fold the singular "-y"/"-ie" endings onto the "-ies" plural key.
    if key.hasSuffix("ie"), key.count > 3 {
      key = String(key.dropLast())
    } else if key.hasSuffix("y"), key.count > 3 {
      key = String(key.dropLast()) + "i"
    }

    return key
  }

  static func dedupePreservingOrder(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }
}
