import MnesiaCore
import SwiftUI
import UIKit

struct SearchScreen: View {
  @ObservedObject var model: AppModel
  @Environment(\.openURL) private var openURL

  private let grid = [GridItem(.adaptive(minimum: 180), spacing: 16)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header

          if !model.authorizationState.canBrowseLibrary {
            PermissionGateView(
              state: model.authorizationState,
              requestAction: {
                Task { await model.requestPhotoAccess() }
              },
              settingsAction: openSystemSettings
            )
          }

          metrics
          controls
          IndexingBannerView(state: model.indexState, cancelAction: model.cancelIndexing)

          if model.searchResults.isEmpty {
            emptyState
          } else {
            LazyVGrid(columns: grid, spacing: 16) {
              ForEach(model.searchResults) { result in
                AssetTileView(model: model, result: result)
              }
            }
          }
        }
        .padding(20)
      }
      .background(background)
      .navigationTitle("mnesia")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker("Sort", selection: $model.sortMode) {
              ForEach(SearchSortMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
          } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
          }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 16) {
        BrandMarkView()

        VStack(alignment: .leading, spacing: 8) {
          Text("Private memory search for the photo library already on your phone.")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(MnesiaTheme.textPrimary)

          Text("mnesia indexes photos and videos on-device using local Apple frameworks, then searches by plain language, time hints, media type, and recognized text.")
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .mnesiaCard()
  }

  private var metrics: some View {
    HStack(spacing: 14) {
      MetricCardView(
        title: "Library",
        value: model.libraryCountLabel,
        detail: "Stored in a local JSON index"
      )

      MetricCardView(
        title: "Results",
        value: model.resultCountLabel,
        detail: "Ranked on-device"
      )
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 16) {
      LocalSearchField(text: $model.searchText)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(SearchScope.allCases) { scope in
            Button {
              model.selectedScope = scope
            } label: {
              Text(scope.title)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                  Capsule()
                    .fill(model.selectedScope == scope ? MnesiaTheme.accent.opacity(0.22) : MnesiaTheme.surfaceRaised)
                )
                .overlay(
                  Capsule()
                    .strokeBorder(model.selectedScope == scope ? MnesiaTheme.accent : .white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(scope.title)")
            .accessibilityAddTraits(model.selectedScope == scope ? .isSelected : [])
          }
        }
      }

      HStack(spacing: 12) {
        if model.isIndexing {
          Button(role: .cancel) {
            model.cancelIndexing()
          } label: {
            Label("Stop indexing", systemImage: "stop.circle")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        } else {
          Button {
            model.startIndexing()
          } label: {
            Label("Update local index", systemImage: "arrow.triangle.2.circlepath")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(MnesiaTheme.accent)
          .disabled(!model.authorizationState.canBrowseLibrary)
          .accessibilityHint("Analyzes new or changed photos on this device.")
        }
      }
    }
    .mnesiaCard()
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("No local matches yet")
        .font(.system(.headline, design: .rounded, weight: .bold))
      Text("Grant photo access and build the local index, or broaden the search prompt if the library is already indexed.")
        .font(.system(.subheadline, design: .monospaced))
        .foregroundStyle(MnesiaTheme.textSecondary)
    }
    .mnesiaCard()
  }

  private var background: some View {
    LinearGradient(
      colors: [
        Color(red: 0.05, green: 0.08, blue: 0.14),
        MnesiaTheme.background,
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    openURL(url)
  }
}
