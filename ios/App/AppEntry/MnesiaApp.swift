import SwiftUI

@main
struct MnesiaApp: App {
  @StateObject private var model = AppContainer.makeAppModel()

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
    }
  }
}
