import SwiftUI

struct BrandMarkView: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              MnesiaTheme.surfaceRaised,
              Color(red: 0.06, green: 0.10, blue: 0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      Path { path in
        path.move(to: CGPoint(x: 20, y: 20))
        path.addLine(to: CGPoint(x: 40, y: 18))
        path.addLine(to: CGPoint(x: 48, y: 36))
        path.addLine(to: CGPoint(x: 18, y: 44))
        path.closeSubpath()
      }
      .stroke(MnesiaTheme.accentSecondary, lineWidth: 2)

      Circle()
        .fill(Color(red: 1.0, green: 0.74, blue: 0.44))
        .frame(width: 10, height: 10)
        .offset(x: -12, y: 8)

      Circle()
        .fill(MnesiaTheme.accent)
        .frame(width: 10, height: 10)
        .offset(x: 10, y: -10)

      Circle()
        .fill(Color(red: 0.56, green: 0.96, blue: 0.76))
        .frame(width: 10, height: 10)
        .offset(x: 14, y: 14)
    }
    .frame(width: 56, height: 56)
    .accessibilityHidden(true)
  }
}
