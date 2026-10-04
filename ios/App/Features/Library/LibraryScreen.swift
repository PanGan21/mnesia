import SwiftUI

struct LibraryScreen: View {
  @ObservedObject var model: AppModel

  private let grid = [GridItem(.adaptive(minimum: 180), spacing: 16)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Library")
              .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Every indexed asset stays tied to the system photo library. mnesia only stores the local metadata it needs for search.")
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)
          }

          if let lastIndexedAt = model.lastIndexedAt {
            MetricCardView(
              title: "Last build",
              value: lastIndexedAt.formatted(date: .abbreviated, time: .shortened),
              detail: model.libraryCountLabel
            )
          }

          if model.indexedRecords.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("Nothing indexed yet")
                .font(.system(.headline, design: .rounded, weight: .bold))
              Text("Build the local index from the Search tab once the app has photo access.")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(MnesiaTheme.textSecondary)
            }
            .mnesiaCard()
          } else {
            LazyVGrid(columns: grid, spacing: 16) {
              ForEach(model.libraryResults) { result in
                AssetTileView(model: model, result: result)
              }
            }
          }
        }
        .padding(20)
      }
      .background(MnesiaTheme.background.ignoresSafeArea())
      .navigationTitle("Indexed Library")
    }
  }
}
