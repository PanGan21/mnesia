import MnesiaCore
import SwiftUI
import UIKit

struct AssetTileView: View {
  @ObservedObject var model: AppModel
  let result: SearchResult

  @State private var thumbnail: UIImage?
  @State private var thumbnailUnavailable = false

  var body: some View {
    Button {
      model.selectedResult = result
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(MnesiaTheme.surfaceRaised)
            .frame(height: 160)
            .overlay {
              if let thumbnail {
                Image(uiImage: thumbnail)
                  .resizable()
                  .scaledToFill()
                  .frame(height: 160)
                  .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
              } else if thumbnailUnavailable {
                Image(systemName: "icloud.slash")
                  .font(.title2)
                  .foregroundStyle(MnesiaTheme.textSecondary)
              } else {
                ProgressView()
                  .tint(MnesiaTheme.accent)
              }
            }
            .accessibilityHidden(true)

          Text(result.record.mediaKind.displayName)
            .font(.system(.caption2, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
        }

        Text(result.record.title)
          .font(.system(.headline, design: .rounded, weight: .semibold))
          .foregroundStyle(MnesiaTheme.textPrimary)
          .lineLimit(2)

        Text(result.record.createdAt.formatted(date: .abbreviated, time: .omitted))
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(MnesiaTheme.textSecondary)

        if !result.matchedTerms.isEmpty {
          Text(result.matchedTerms.joined(separator: ", "))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(MnesiaTheme.accent)
            .lineLimit(2)
            .accessibilityLabel("Matched \(result.matchedTerms.joined(separator: ", "))")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .mnesiaCard()
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityValue(result.record.isFavorite ? "Favorite" : "")
    .accessibilityHint("Opens a preview")
    .task(id: result.record.id) {
      await loadThumbnail()
    }
  }

  private func loadThumbnail() async {
    guard thumbnail == nil else {
      return
    }

    let image = await model.loadThumbnail(
      for: result.record.id,
      targetSize: CGSize(width: 520, height: 520)
    )
    // A cancelled load (tile scrolled away) leaves the spinner so it retries on reappear.
    guard !Task.isCancelled else {
      return
    }
    thumbnail = image
    thumbnailUnavailable = image == nil
  }
}
