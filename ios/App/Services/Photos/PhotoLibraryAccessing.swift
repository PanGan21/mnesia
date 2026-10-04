import CoreGraphics
import MnesiaCore
import UIKit

/// Read-only access to the system photo library. Implementations must never enable network
/// access, so assets that are only stored in iCloud are reported as unavailable.
protocol PhotoLibraryAccessing: LibraryAssetCatalog {
  func authorizationState() -> PhotoAuthorizationState
  func requestAuthorization() async -> PhotoAuthorizationState
  /// A downsampled still (or video frame) suitable for Vision analysis.
  func loadAnalysisInput(for descriptor: LibraryAssetDescriptor) async throws -> AssetAnalysisInput
  func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async throws -> UIImage
  @MainActor
  func loadDisplayAsset(for localIdentifier: String, maximumImageSize: CGSize) async throws -> DisplayAssetPayload
}
