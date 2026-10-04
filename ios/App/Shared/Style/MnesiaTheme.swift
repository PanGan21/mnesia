import SwiftUI

enum MnesiaTheme {
  static let background = Color(red: 0.03, green: 0.07, blue: 0.13)
  static let surface = Color(red: 0.06, green: 0.11, blue: 0.19)
  static let surfaceRaised = Color(red: 0.08, green: 0.15, blue: 0.24)
  static let textPrimary = Color(red: 0.95, green: 0.97, blue: 0.99)
  static let textSecondary = Color(red: 0.62, green: 0.69, blue: 0.79)
  static let accent = Color(red: 0.44, green: 0.92, blue: 0.98)
  static let accentSecondary = Color(red: 0.55, green: 0.72, blue: 1.00)
}

struct MnesiaCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(18)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(MnesiaTheme.surface.opacity(0.88))
          .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
              .strokeBorder(.white.opacity(0.08))
          )
      )
  }
}

extension View {
  func mnesiaCard() -> some View {
    modifier(MnesiaCardModifier())
  }
}
