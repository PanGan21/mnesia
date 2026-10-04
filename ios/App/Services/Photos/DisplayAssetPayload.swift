import AVFoundation
import UIKit

/// Content for the full-screen preview. Created and consumed on the main actor.
@MainActor
enum DisplayAssetPayload {
  case photo(UIImage)
  case video(AVPlayer)
}
