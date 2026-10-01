import SwiftUI

/// Bybit-layout order-ticket controls for ``TradeOrderView`` (§9.6). Brand palette, not exchange
/// orange: **green = Купить / buy / up**, **red = Продать / sell / down** (semantic state), neutrals
/// for everything else. Text color on the green/red fills is chosen by ``Color/bestOnColor`` for AA contrast.

/// Купить (green) / Продать (red) tab — the colored two-segment toggle at the top of the ticket.
struct TradeSideToggle: View {
    @Binding var side: CryptoSide
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            segment("Купить", .buy, theme.success)
            segment("Продать", .sell, theme.danger)
        }
        .padding(2)
        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    private func segment(_ title: String, _ value: CryptoSide, _ color: Color) -> some View {
        let selected = side == value
        return Button { side = value } label: {
            Text(title)
                .font(BrandFont.headline)
                .foregroundStyle(selected ? color.bestOnColor : theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A labeled numeric entry (Цена / Количество / Объём) with optional ± steppers — the ticket's row.
struct TicketField: View {
    let label: String
    @Binding var text: String
    var unit: String
    var enabled: Bool = true
    var placeholder: String = "0"
    /// > 0 shows ± steppers calling `onStep(±step)`.
    var step: Double = 0
    var onStep: (Double) -> Void = { _ in }

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            HStack(spacing: Spacing.sm) {
                if step > 0 && enabled { stepButton("minus") { onStep(-step) } }
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(BrandFont.mono(18, weight: .medium))
                    .foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary)
                    .multilineTextAlignment((step > 0 && enabled) ? .center : .leading)
                    .disabled(!enabled)
                if !unit.isEmpty {
                    Text(unit).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
                if step > 0 && enabled { stepButton("plus") { onStep(step) } }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 48)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(theme.fill))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// The 25 / 50 / 75 / 100 % size selector with a continuous slider — % of available balance.
struct PercentSelector: View {
    @Binding var fraction: Double
    @Environment(\.theme) private var theme

    private let stops: [Double] = [0.25, 0.5, 0.75, 1.0]
    private func isOn(_ s: Double) -> Bool { abs(fraction - s) < 0.001 }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Slider(value: $fraction, in: 0...1)
                .tint(theme.accent)
            HStack(spacing: Spacing.sm) {
                ForEach(stops, id: \.self) { s in
                    Button { fraction = s } label: {
                        Text(MoneyFormat.percent(fraction: s, maxFractionDigits: 0))
                            .font(BrandFont.footnote.weight(.medium))
                            .foregroundStyle(isOn(s) ? theme.background : theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(isOn(s) ? theme.textPrimary : theme.fill,
                                        in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }
}

/// The large green (buy) / red (sell) action button used in the asset detail and the order ticket.
/// Text only (docs/DESIGN.md §5): `icon` is accepted for source compatibility and ignored.
struct TradeActionButton: View {
    let title: String
    var side: CryptoSide
    var icon: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    private var color: Color { side == .buy ? theme.success : theme.danger }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(color.bestOnColor)
                }
                Text(title).font(BrandFont.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(color.bestOnColor)
            .background(color)
            .opacity(isEnabled && !isLoading ? 1 : 0.45)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
    }
}
