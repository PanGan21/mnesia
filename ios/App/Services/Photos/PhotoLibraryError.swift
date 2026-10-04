import Foundation

enum PhotoLibraryError: LocalizedError, Equatable {
  case assetUnavailable
  case assetOnlyInICloud
  case invalidImageData
  case previewGenerationFailed

  var errorDescription: String? {
    switch self {
    case .assetUnavailable:
      return "The requested photo asset is no longer available."
    case .assetOnlyInICloud:
      return "This asset is only available in iCloud. mnesia keeps network access disabled."
    case .invalidImageData:
      return "The asset data could not be decoded into an image for local analysis."
    case .previewGenerationFailed:
      return "mnesia could not generate a local preview for this asset."
    }
  }
}
