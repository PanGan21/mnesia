import MnesiaCore
import SwiftUI

struct IndexingBannerView: View {
  let state: AppModel.IndexState
  let cancelAction: () -> Void

  var body: some View {
    switch state {
    case .idle:
      EmptyView()
    case .indexing(let progress):
      VStack(alignment: .leading, spacing: 12) {
        Text("Updating local index")
          .font(.system(.headline, design: .rounded, weight: .bold))
        ProgressView(value: progress.fractionCompleted) {
          Text(progressTitle(progress))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
        }
        .tint(MnesiaTheme.accent)
        if let issues = issueLine(skipped: progress.skippedCount, failed: progress.failedCount) {
          Text(issues)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
        }
        Button("Stop", role: .cancel, action: cancelAction)
          .buttonStyle(.bordered)
          .accessibilityHint("Stops indexing and keeps the items analyzed so far.")
      }
      .mnesiaCard()
    case .completed(let date, let summary):
      VStack(alignment: .leading, spacing: 8) {
        Text("Local index ready")
          .font(.system(.headline, design: .rounded, weight: .bold))
        Text("Last update: \(date.formatted(date: .abbreviated, time: .shortened))")
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(MnesiaTheme.textSecondary)
        if let summary {
          summaryLines(summary)
        }
      }
      .accessibilityElement(children: .combine)
      .mnesiaCard()
    case .cancelled(let summary):
      VStack(alignment: .leading, spacing: 8) {
        Text("Indexing stopped")
          .font(.system(.headline, design: .rounded, weight: .bold))
        Text("\(summary.pendingCount) items were not analyzed yet. Update the index to continue.")
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(MnesiaTheme.textSecondary)
        summaryLines(summary)
      }
      .accessibilityElement(children: .combine)
      .mnesiaCard()
    case .failed(let message):
      VStack(alignment: .leading, spacing: 8) {
        Label("Indexing hit a problem", systemImage: "exclamationmark.triangle")
          .font(.system(.headline, design: .rounded, weight: .bold))
        Text(message)
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(MnesiaTheme.textSecondary)
      }
      .accessibilityElement(children: .combine)
      .mnesiaCard()
    }
  }

  private func progressTitle(_ progress: IndexingProgress) -> String {
    if progress.totalCount == 0 {
      return "Scanning your photo library…"
    }
    return "Analyzing \(min(progress.processedCount + 1, progress.totalCount)) of \(progress.totalCount) new or changed items"
  }

  @ViewBuilder
  private func summaryLines(_ summary: IndexingSummary) -> some View {
    Text("\(summary.analyzedCount) analyzed, \(summary.reusedCount) unchanged, \(summary.removedCount) removed")
      .font(.system(.footnote, design: .monospaced))
      .foregroundStyle(MnesiaTheme.textSecondary)
    if let issues = issueLine(skipped: summary.skippedCount, failed: summary.failedCount) {
      Text(issues)
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(MnesiaTheme.textSecondary)
    }
  }

  private func issueLine(skipped: Int, failed: Int) -> String? {
    var parts: [String] = []
    if skipped > 0 {
      parts.append("\(skipped) skipped because they are only in iCloud (mnesia never downloads)")
    }
    if failed > 0 {
      parts.append("\(failed) could not be analyzed and will be retried next time")
    }
    return parts.isEmpty ? nil : parts.joined(separator: "; ") + "."
  }
}
