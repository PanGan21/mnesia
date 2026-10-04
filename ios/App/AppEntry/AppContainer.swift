import Foundation
import MnesiaCore

enum AppContainer {
  @MainActor
  static func makeAppModel() -> AppModel {
    let indexURL = URL.applicationSupportDirectory
      .appending(path: "Mnesia", directoryHint: .isDirectory)
      .appending(path: "local-index.json", directoryHint: .notDirectory)

    let photoLibrary = PhotoLibraryService()
    let indexer = LibraryIndexer(
      catalog: photoLibrary,
      analyzer: PhotoLibraryAnalysisPipeline(
        photoLibrary: photoLibrary,
        analyzer: VisionSemanticAnalyzer()
      )
    )

    return AppModel(
      photoLibrary: photoLibrary,
      indexStore: JSONIndexStore(fileURL: indexURL),
      indexer: indexer
    )
  }
}
