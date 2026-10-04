import SwiftUI

struct MetricCardView: View {
  let title: String
  let value: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(MnesiaTheme.textSecondary)

      Text(value)
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundStyle(MnesiaTheme.textPrimary)

      Text(detail)
        .font(.system(.subheadline, design: .monospaced))
        .foregroundStyle(MnesiaTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .mnesiaCard()
  }
}
