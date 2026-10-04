import SwiftUI

struct LocalSearchField: View {
  @Binding var text: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "sparkle.magnifyingglass")
        .foregroundStyle(MnesiaTheme.accent)
        .accessibilityHidden(true)

      TextField("Describe what you remember", text: $text)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .accessibilityLabel("Search your library")

      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(MnesiaTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(MnesiaTheme.surfaceRaised.opacity(0.92))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(.white.opacity(0.08))
        )
    )
  }
}
