import SwiftUI

struct PermissionGateView: View {
  let state: PhotoAuthorizationState
  let requestAction: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center, spacing: 14) {
        BrandMarkView()

        VStack(alignment: .leading, spacing: 6) {
          Text(state.title)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(MnesiaTheme.textPrimary)

          Text(state.detail)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(MnesiaTheme.textSecondary)
        }
      }

      HStack(spacing: 12) {
        if state == .notDetermined {
          Button("Allow Photo Access", action: requestAction)
            .buttonStyle(.borderedProminent)
            .tint(MnesiaTheme.accent)
        } else if state == .denied || state == .limited {
          Button(state == .limited ? "Change Access in Settings" : "Open Settings", action: settingsAction)
            .buttonStyle(.bordered)
            .tint(MnesiaTheme.accentSecondary)
        }
      }
    }
    .mnesiaCard()
  }
}
