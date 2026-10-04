import CoreGraphics
import ImageIO

/// A downsampled frame handed to on-device analysis.
struct AssetAnalysisInput: Sendable {
  let cgImage: CGImage
  let orientation: CGImagePropertyOrientation
}
