import AVFoundation
import ImageIO
import MnesiaCore
import Photos
import UIKit
import os

/// PhotoKit-backed library access.
///
/// Deliberately not main-actor isolated: `PHAsset`, `PHImageManager` and
/// `PHCachingImageManager` are thread-safe (`Sendable`), so enumeration and image decoding run on
/// the cooperative pool instead of blocking the UI. Every request disables network access, so
/// iCloud-only originals surface as `PhotoLibraryError.assetOnlyInICloud` instead of being
/// downloaded.
final class PhotoLibraryService: PhotoLibraryAccessing {
  /// Longest edge, in pixels, of frames handed to Vision. Large enough for legible OCR, small
  /// enough to keep peak memory per asset at a few MB instead of a full-resolution decode.
  static let analysisMaxPixelSize: CGFloat = 1600

  private let imageManager = PHCachingImageManager()

  func authorizationState() -> PhotoAuthorizationState {
    PhotoAuthorizationState(status: PHPhotoLibrary.authorizationStatus(for: .readWrite))
  }

  func requestAuthorization() async -> PhotoAuthorizationState {
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return PhotoAuthorizationState(status: status)
  }

  // MARK: LibraryAssetCatalog

  func fetchAssetDescriptors() async throws -> [LibraryAssetDescriptor] {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.predicate = NSPredicate(
      format: "mediaType == %d || mediaType == %d",
      PHAssetMediaType.image.rawValue,
      PHAssetMediaType.video.rawValue
    )

    let results = PHAsset.fetchAssets(with: options)
    var descriptors: [LibraryAssetDescriptor] = []
    descriptors.reserveCapacity(results.count)

    results.enumerateObjects { asset, _, stop in
      if Task.isCancelled {
        stop.pointee = true
        return
      }
      descriptors.append(Self.makeDescriptor(from: asset))
    }

    try Task.checkCancellation()
    return descriptors
  }

  // MARK: Analysis

  func loadAnalysisInput(for descriptor: LibraryAssetDescriptor) async throws -> AssetAnalysisInput {
    let asset = try fetchAsset(localIdentifier: descriptor.id)
    let maxSize = CGSize(width: Self.analysisMaxPixelSize, height: Self.analysisMaxPixelSize)

    switch descriptor.mediaKind {
    case .video:
      do {
        return try await loadVideoFrame(for: asset, maximumSize: maxSize)
      } catch PhotoLibraryError.assetOnlyInICloud {
        // The video file is not local, but Photos usually keeps a local poster frame.
        return try await loadStillImage(for: asset, targetSize: maxSize)
      }
    case .photo, .screenshot:
      return try await loadStillImage(for: asset, targetSize: maxSize)
    }
  }

  // MARK: Display

  func loadThumbnail(for localIdentifier: String, targetSize: CGSize) async throws -> UIImage {
    let asset = try fetchAsset(localIdentifier: localIdentifier)
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = false

    return try await requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  @MainActor
  func loadDisplayAsset(for localIdentifier: String, maximumImageSize: CGSize) async throws -> DisplayAssetPayload {
    switch try await loadDisplayContent(for: localIdentifier, maximumImageSize: maximumImageSize) {
    case .photo(let image):
      return .photo(image)
    case .video(let item):
      return .video(AVPlayer(playerItem: item.value))
    }
  }

  /// Loads preview content off the main actor; only the `AVPlayer` is created on the main actor.
  private func loadDisplayContent(
    for localIdentifier: String,
    maximumImageSize: CGSize
  ) async throws -> DisplayContent {
    let asset = try fetchAsset(localIdentifier: localIdentifier)

    if asset.mediaType == .video {
      let options = PHVideoRequestOptions()
      options.deliveryMode = .automatic
      options.isNetworkAccessAllowed = false
      options.version = .current

      let item = try await performRequest { complete in
        imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
          complete(Self.result(playerItem.map(UncheckedTransfer.init), info: info))
        }
      }
      return .video(item)
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = false
    options.version = .current

    let image = try await requestImage(
      for: asset,
      targetSize: maximumImageSize,
      contentMode: .aspectFit,
      options: options
    )
    return .photo(image)
  }

  private enum DisplayContent: Sendable {
    case photo(UIImage)
    case video(UncheckedTransfer<AVPlayerItem>)
  }

  // MARK: Private

  private static func makeDescriptor(from asset: PHAsset) -> LibraryAssetDescriptor {
    let mediaKind: AssetMediaKind
    if asset.mediaType == .video {
      mediaKind = .video
    } else if asset.mediaSubtypes.contains(.photoScreenshot) {
      mediaKind = .screenshot
    } else {
      mediaKind = .photo
    }

    // Note: resource lookup is the slowest part of enumeration; it runs off the main actor.
    let title = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Untitled"
    let createdAt = asset.creationDate ?? asset.modificationDate ?? .distantPast

    // Content fingerprint: edits bump `modificationDate`, and pixel size/duration catch the
    // rest. Any change triggers re-analysis; metadata-only changes are cheap to re-analyze.
    let version = [
      "\(asset.pixelWidth)x\(asset.pixelHeight)",
      String(asset.duration),
      String(asset.modificationDate?.timeIntervalSince1970 ?? 0),
    ].joined(separator: "|")

    return LibraryAssetDescriptor(
      id: asset.localIdentifier,
      title: title,
      mediaKind: mediaKind,
      createdAt: createdAt,
      duration: asset.mediaType == .video ? asset.duration : nil,
      pixelWidth: asset.pixelWidth,
      pixelHeight: asset.pixelHeight,
      isFavorite: asset.isFavorite,
      hasLocation: asset.location != nil,
      assetVersion: version
    )
  }

  private func fetchAsset(localIdentifier: String) throws -> PHAsset {
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
      throw PhotoLibraryError.assetUnavailable
    }
    return asset
  }

  /// Requests a downsampled still from Photos. Photos serves this from its local derivatives
  /// when possible, which also works for many "Optimize iPhone Storage" assets whose original
  /// lives only in iCloud.
  private func loadStillImage(for asset: PHAsset, targetSize: CGSize) async throws -> AssetAnalysisInput {
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = false
    options.version = .current

    let image = try await requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options)
    guard let cgImage = image.cgImage else {
      throw PhotoLibraryError.invalidImageData
    }
    return AssetAnalysisInput(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
  }

  private func loadVideoFrame(for asset: PHAsset, maximumSize: CGSize) async throws -> AssetAnalysisInput {
    let options = PHVideoRequestOptions()
    options.deliveryMode = .fastFormat
    options.isNetworkAccessAllowed = false
    options.version = .current

    let transfer = try await performRequest { complete in
      imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
        complete(Self.result(avAsset.map(UncheckedTransfer.init), info: info))
      }
    }
    let avAsset = transfer.value

    let generator = AVAssetImageGenerator(asset: avAsset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maximumSize

    let duration = try await avAsset.load(.duration)
    let durationSeconds = CMTimeGetSeconds(duration)
    // Skip fade-ins: sample a little into the clip, but never past 2.5s.
    let preferredSecond = durationSeconds.isFinite && durationSeconds > 0
      ? min(max(durationSeconds * 0.18, 0.15), 2.5)
      : 0.0
    let time = CMTime(seconds: preferredSecond, preferredTimescale: 600)

    do {
      let (cgImage, _) = try await generator.image(at: time)
      return AssetAnalysisInput(cgImage: cgImage, orientation: .up)
    } catch let error as CancellationError {
      throw error
    } catch {
      throw PhotoLibraryError.previewGenerationFailed
    }
  }

  private func requestImage(
    for asset: PHAsset,
    targetSize: CGSize,
    contentMode: PHImageContentMode,
    options: PHImageRequestOptions
  ) async throws -> UIImage {
    // `.highQualityFormat` guarantees a single callback, so the request resolves exactly once.
    assert(options.deliveryMode == .highQualityFormat)
    return try await performRequest { complete in
      imageManager.requestImage(
        for: asset,
        targetSize: targetSize,
        contentMode: contentMode,
        options: options
      ) { image, info in
        complete(Self.result(image, info: info))
      }
    }
  }

  /// Bridges a PhotoKit callback request to async/await. The continuation is resumed exactly
  /// once, and cancelling the calling task cancels the underlying PhotoKit request.
  private func performRequest<Value: Sendable>(
    _ start: (_ complete: @escaping @Sendable (Result<Value, any Error>) -> Void) -> PHImageRequestID
  ) async throws -> Value {
    let request = PendingPhotoRequest<Value>()
    let manager = imageManager
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        guard request.attach(continuation) else {
          return
        }
        let requestID = start { result in
          request.finish(with: result)
        }
        request.setRequestID(requestID, cancel: { manager.cancelImageRequest($0) })
      }
    } onCancel: {
      request.cancel { manager.cancelImageRequest($0) }
    }
  }

  /// Interprets PhotoKit's result `info` dictionary.
  private static func result<Value>(_ value: Value?, info: [AnyHashable: Any]?) -> Result<Value, any Error> {
    if (info?[PHImageCancelledKey] as? Bool) == true {
      return .failure(CancellationError())
    }
    if let error = info?[PHImageErrorKey] as? any Error {
      return .failure(error)
    }
    if let value {
      return .success(value)
    }
    if (info?[PHImageResultIsInCloudKey] as? Bool) == true {
      return .failure(PhotoLibraryError.assetOnlyInICloud)
    }
    return .failure(PhotoLibraryError.invalidImageData)
  }
}

/// Moves a non-`Sendable` AVFoundation object from PhotoKit's callback queue to the awaiting
/// task. Safe because PhotoKit hands over ownership and never touches the object afterwards,
/// and the receiver is its only user from then on.
private struct UncheckedTransfer<Value>: @unchecked Sendable {
  let value: Value
}

/// State for one in-flight PhotoKit request, guarded by a lock because the result handler,
/// the cancellation handler and the requesting task can race.
private final class PendingPhotoRequest<Value: Sendable>: Sendable {
  private struct State: Sendable {
    var continuation: CheckedContinuation<Value, any Error>?
    var requestID: PHImageRequestID?
    var isCancelled = false
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  /// Stores the continuation; returns `false` (after resuming it) if already cancelled.
  func attach(_ continuation: CheckedContinuation<Value, any Error>) -> Bool {
    let isCancelled = state.withLock { state in
      if !state.isCancelled {
        state.continuation = continuation
      }
      return state.isCancelled
    }
    if isCancelled {
      continuation.resume(throwing: CancellationError())
    }
    return !isCancelled
  }

  func setRequestID(_ requestID: PHImageRequestID, cancel: (PHImageRequestID) -> Void) {
    let cancelNow = state.withLock { state in
      state.requestID = requestID
      return state.isCancelled
    }
    if cancelNow {
      cancel(requestID)
    }
  }

  func finish(with result: Result<Value, any Error>) {
    let continuation = state.withLock { state in
      defer { state.continuation = nil }
      return state.continuation
    }
    continuation?.resume(with: result)
  }

  func cancel(_ cancelRequest: (PHImageRequestID) -> Void) {
    let requestID = state.withLock { state in
      state.isCancelled = true
      return state.requestID
    }
    if let requestID {
      cancelRequest(requestID)
    }
    finish(with: .failure(CancellationError()))
  }
}

private extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
