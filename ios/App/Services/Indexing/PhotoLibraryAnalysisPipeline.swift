import Foundation
import MnesiaCore
import os

/// Adapts PhotoKit loading + Vision analysis to the core `LibraryAssetAnalyzing` contract and
/// translates expected PhotoKit failures into `AssetAnalysisError`.
struct PhotoLibraryAnalysisPipeline: LibraryAssetAnalyzing {
  private static let logger = Logger(subsystem: "com.panagiotisganelis.mnesia", category: "indexing")

  let photoLibrary: any PhotoLibraryAccessing
  let analyzer: any VisionAssetAnalyzing

  func analyze(_ descriptor: LibraryAssetDescriptor) async throws -> AssetSemanticAnalysis {
    do {
      let input = try await photoLibrary.loadAnalysisInput(for: descriptor)
      return try await analyzer.analyze(input)
    } catch PhotoLibraryError.assetOnlyInICloud {
      throw AssetAnalysisError.notAvailableLocally
    } catch PhotoLibraryError.assetUnavailable {
      throw AssetAnalysisError.assetMissing
    } catch let error as CancellationError {
      throw error
    } catch {
      // Identifiers and error details stay private in the unified log.
      Self.logger.error(
        "Analysis failed for asset \(descriptor.id, privacy: .private): \(error.localizedDescription, privacy: .private)"
      )
      throw error
    }
  }
}
