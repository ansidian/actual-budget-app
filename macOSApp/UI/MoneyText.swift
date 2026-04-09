import SwiftUI

/// Renders a cents amount as a currency string with appropriate styling.
struct MoneyText: View {
    let amount: Int?
    var currencyCode: String
    var signed: Bool = false
    var emphasis: Bool = false

    var body: some View {
        let value = amount ?? 0
        let text = signed
            ? CurrencyFormatter.shared.formatSigned(value, currencyCode: currencyCode)
            : CurrencyFormatter.shared.format(value, currencyCode: currencyCode)
        Text(text)
            .monospacedDigit()
            .fontWeight(emphasis ? .semibold : .regular)
            .foregroundStyle(color(for: value))
    }

    private func color(for value: Int) -> Color {
        if value < 0 { return .primary }
        if value > 0 && signed { return .green }
        return .primary
    }
}
