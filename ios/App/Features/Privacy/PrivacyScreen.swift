import SwiftUI

struct PrivacyScreen: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Privacy")
              .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("mnesia is designed so the search value comes from local indexing, not from exporting your library.")
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)
          }

          privacyCard(
            title: "What stays on-device",
            points: [
              "Photo library access is read from PhotoKit on the device.",
              "Tags, OCR text, and ranking data are written to encrypted local app storage and excluded from device backups.",
              "mnesia never enables network access for Photos, so iCloud-only assets are skipped instead of downloaded.",
            ]
          )

          privacyCard(
            title: "What you control",
            points: [
              "Use limited library access if you only want to expose selected items.",
              "Update the index when your library changes; only new or edited items are re-analyzed.",
              "Clear the local index at any time without touching the Photos library itself.",
            ]
          )

          privacyCard(
            title: "Current app state",
            points: [
              model.authorizationState.detail,
              model.lastIndexedAt.map { "Last local build: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "No local index has been built yet.",
            ]
          )
        }
        .padding(20)
      }
      .background(MnesiaTheme.background.ignoresSafeArea())
      .navigationTitle("Privacy")
    }
  }

  private func privacyCard(title: String, points: [String]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(.headline, design: .rounded, weight: .bold))

      ForEach(points, id: \.self) { point in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(MnesiaTheme.accent)
            .accessibilityHidden(true)

          Text(point)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .mnesiaCard()
  }
}
