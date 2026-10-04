import SwiftUI
import UIKit

struct SettingsScreen: View {
  @ObservedObject var model: AppModel
  @Environment(\.openURL) private var openURL
  @State private var isConfirmingClear = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
              .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Tune the local indexing workflow without sending your library anywhere.")
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("Access")
              .font(.system(.headline, design: .rounded, weight: .bold))

            Text(model.authorizationState.detail)
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)

            if model.authorizationState != .authorized && model.authorizationState != .notDetermined {
              Button("Change Photo Access in Settings", action: openSystemSettings)
                .buttonStyle(.bordered)
                .tint(MnesiaTheme.accentSecondary)
            }

            if let lastIndexedAt = model.lastIndexedAt {
              Text("Last local build: \(lastIndexedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(MnesiaTheme.textSecondary)
            }
          }
          .mnesiaCard()

          VStack(alignment: .leading, spacing: 12) {
            Text("Local Index")
              .font(.system(.headline, design: .rounded, weight: .bold))

            Text("Updating only analyzes new or edited items. Re-analyze everything after an app update, or clear the saved metadata while leaving the Photos library untouched.")
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(MnesiaTheme.textSecondary)

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

              Button {
                model.startIndexing(mode: .full)
              } label: {
                Label("Re-analyze everything", systemImage: "sparkles")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .disabled(!model.authorizationState.canBrowseLibrary)
            }

            Button(role: .destructive) {
              isConfirmingClear = true
            } label: {
              Label("Clear local index", systemImage: "trash")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
              "Clear the local index?",
              isPresented: $isConfirmingClear,
              titleVisibility: .visible
            ) {
              Button("Clear Index", role: .destructive) {
                Task { await model.clearLocalIndex() }
              }
            } message: {
              Text("Your photos are not affected. Search stays empty until the index is rebuilt.")
            }
          }
          .mnesiaCard()
        }
        .padding(20)
      }
      .background(MnesiaTheme.background.ignoresSafeArea())
      .navigationTitle("Settings")
    }
  }

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    openURL(url)
  }
}
