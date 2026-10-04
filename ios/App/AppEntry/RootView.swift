import SwiftUI

struct RootView: View {
  @ObservedObject var model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView {
      SearchScreen(model: model)
        .tabItem {
          Label("Search", systemImage: "sparkle.magnifyingglass")
        }

      LibraryScreen(model: model)
        .tabItem {
          Label("Library", systemImage: "photo.stack")
        }

      PrivacyScreen(model: model)
        .tabItem {
          Label("Privacy", systemImage: "lock.shield")
        }

      SettingsScreen(model: model)
        .tabItem {
          Label("Settings", systemImage: "slider.horizontal.3")
        }
    }
    .task {
      await model.loadIfNeeded()
    }
    .onChange(of: scenePhase) { _, phase in
      // Photo access may have been changed in the Settings app while backgrounded.
      if phase == .active {
        model.refreshAuthorization()
      }
    }
    .sheet(item: $model.selectedResult) { result in
      AssetPreviewSheet(model: model, result: result)
        .presentationDetents([.large])
    }
  }
}
