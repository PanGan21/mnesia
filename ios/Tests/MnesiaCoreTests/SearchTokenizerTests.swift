import Testing
@testable import MnesiaCore

@Suite("SearchTokenizer")
struct SearchTokenizerTests {
  @Test func splitsOnPunctuationAndDropsStopWordsAndSingleCharacters() {
    #expect(SearchTokenizer.tokenize("The dog_park-sunset, at 5 PM!") == ["dog", "park", "sunset", "pm"])
  }

  @Test func foldsCaseAndDiacritics() {
    #expect(SearchTokenizer.tokenize("Café CRÈME Brûlée") == ["cafe", "creme", "brulee"])
  }

  @Test func keepsNumbers() {
    #expect(SearchTokenizer.tokenize("route 66 in 2024") == ["route", "66", "2024"])
  }

  @Test(arguments: [
    ("dogs", "dog"),
    ("puppies", "puppy"),
    ("movies", "movie"),
    ("selfies", "selfie"),
    ("cities", "city"),
    ("beaches", "beach"),
    ("boxes", "box"),
    ("dishes", "dish"),
    ("glasses", "glass"),
    ("shoes", "shoe"),
    ("trees", "tree"),
    ("days", "day"),
  ])
  func pluralAndSingularShareAMatchKey(_ plural: String, _ singular: String) {
    #expect(SearchTokenizer.normalize(plural) == SearchTokenizer.normalize(singular))
  }

  @Test(arguments: ["bus", "glass", "cactus", "tennis", "dress", "running", "2024s", "été"])
  func leavesNonPluralsStable(_ word: String) {
    // Normalization must be idempotent so query and index keys always agree.
    let key = SearchTokenizer.normalize(word)
    #expect(SearchTokenizer.normalize(key) == key)
  }

  @Test func doesNotStripSingularEndings() {
    #expect(SearchTokenizer.normalize("glass") == "glass")
    #expect(SearchTokenizer.normalize("cactus") == "cactus")
    #expect(SearchTokenizer.normalize("tennis") == "tennis")
    #expect(SearchTokenizer.normalize("bus") == "bus")
    #expect(SearchTokenizer.normalize("cat") == "cat")
  }

  @Test func dedupePreservesFirstOccurrenceOrder() {
    #expect(SearchTokenizer.dedupePreservingOrder(["b", "a", "b", "c", "a"]) == ["b", "a", "c"])
  }
}
