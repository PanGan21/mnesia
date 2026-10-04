import Foundation
import MnesiaCore

protocol VisionAssetAnalyzing: Sendable {
  func analyze(_ input: AssetAnalysisInput) async throws -> AssetSemanticAnalysis
}
