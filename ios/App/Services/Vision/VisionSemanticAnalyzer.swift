import Foundation
import MnesiaCore
import Vision

/// Runs image classification, text recognition and face detection fully on-device.
/// Stateless, so it is safe to call concurrently.
struct VisionSemanticAnalyzer: VisionAssetAnalyzing {
  private static let minimumClassificationConfidence: Float = 0.15
  private static let maximumTagCount = 8

  func analyze(_ input: AssetAnalysisInput) async throws -> AssetSemanticAnalysis {
    try Task.checkCancellation()

    let classificationRequest = VNClassifyImageRequest()
    let textRequest = VNRecognizeTextRequest()
    textRequest.recognitionLevel = .accurate
    textRequest.usesLanguageCorrection = true
    textRequest.minimumTextHeight = 0.02

    let faceRequest = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(
      cgImage: input.cgImage,
      orientation: input.orientation,
      options: [:]
    )

    // Synchronous and CPU/ANE bound; runs on the caller's (non-main) executor.
    try handler.perform([classificationRequest, textRequest, faceRequest])

    let tags = (classificationRequest.results ?? [])
      .filter { $0.confidence >= Self.minimumClassificationConfidence }
      .prefix(Self.maximumTagCount)
      .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

    let recognizedText = (textRequest.results ?? [])
      .compactMap { $0.topCandidates(1).first?.string }

    let faceCount = faceRequest.results?.count ?? 0
    var notes: [String] = []

    if faceCount == 1 {
      notes.append("person")
      notes.append("portrait")
    } else if faceCount > 1 {
      notes.append("people")
      notes.append("group")
    }

    return AssetSemanticAnalysis(
      tags: sanitize(tags, lowercase: true),
      recognizedText: sanitize(recognizedText, lowercase: false),
      notes: notes
    )
  }

  /// Trims, drops empties and de-duplicates. Recognized text keeps its case for display;
  /// search matching is case-insensitive anyway.
  private func sanitize(_ values: [String], lowercase: Bool) -> [String] {
    var seen = Set<String>()
    return values
      .map { value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return lowercase ? trimmed.lowercased() : trimmed
      }
      .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
  }
}
