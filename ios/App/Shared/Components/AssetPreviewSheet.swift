import AVKit
import MnesiaCore
import SwiftUI

struct AssetPreviewSheet: View {
  @ObservedObject var model: AppModel
  let result: SearchResult

  @State private var payload: DisplayAssetPayload?
  @State private var loadError: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        media

        VStack(alignment: .leading, spacing: 10) {
          Text(result.record.title)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .accessibilityAddTraits(.isHeader)

          Text(result.record.createdAt.formatted(date: .complete, time: .shortened))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
        }

        if !result.record.tags.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("On-device tags")
              .font(.system(.headline, design: .rounded, weight: .semibold))
              .accessibilityAddTraits(.isHeader)

            FlowLayout(items: result.record.tags) { tag in
              Text(tag)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MnesiaTheme.surfaceRaised, in: Capsule())
            }
          }
        }

        if !result.record.recognizedText.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Recognized text")
              .font(.system(.headline, design: .rounded, weight: .semibold))
              .accessibilityAddTraits(.isHeader)
            Text(result.record.recognizedText.joined(separator: "\n"))
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)
              .textSelection(.enabled)
          }
        }
      }
      .padding(20)
    }
    .background(MnesiaTheme.background.ignoresSafeArea())
    .task(id: result.record.id) {
      do {
        payload = try await model.loadDisplayAsset(for: result.record.id)
      } catch is CancellationError {
        return
      } catch {
        loadError = error.localizedDescription
      }
    }
    .onDisappear {
      if case .video(let player) = payload {
        player.pause()
      }
    }
  }

  @ViewBuilder
  private var media: some View {
    if let payload {
      switch payload {
      case .photo(let image):
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
          .accessibilityLabel("\(result.record.mediaKind.displayName): \(result.record.title)")
      case .video(let player):
        VideoPlayer(player: player)
          .frame(minHeight: 280)
          .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
      }
    } else {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(MnesiaTheme.surfaceRaised)
        .frame(height: 280)
        .overlay {
          if let loadError {
            Label(loadError, systemImage: "icloud.slash")
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding()
          } else {
            ProgressView("Loading preview")
              .tint(MnesiaTheme.accent)
          }
        }
    }
  }
}

private struct FlowLayout<Item: Hashable, Content: View>: View {
  let items: [Item]
  let content: (Item) -> Content

  var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 100), spacing: 8, alignment: .leading)],
      alignment: .leading,
      spacing: 8
    ) {
      ForEach(items, id: \.self) { item in
        content(item)
      }
    }
  }
}
