import SwiftUI

/// Bybit-layout order-ticket controls for ``TradeOrderView`` (§9.6). Brand palette, not exchange
/// orange: **green = Купить / buy / up**, **red = Продать / sell / down**, cold gradient for neutral
/// emphasis. Text color on the green/red fills is chosen by ``Color/bestOnColor`` for AA contrast.

/// Купить (green) / Продать (red) tab — the colored two-segment toggle at the top of the ticket.
struct TradeSideToggle: View {
    @Binding var side: CryptoSide
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            segment("Купить", .buy, theme.success)
            segment("Продать", .sell, theme.danger)
        }
        .padding(3)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func segment(_ title: String, _ value: CryptoSide, _ color: Color) -> some View {
        let selected = side == value
        return Button { side = value } label: {
            Text(title)
                .font(BrandFont.headline)
                .foregroundStyle(selected ? color.bestOnColor : theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(color)
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
            Text(label).font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.textSecondary)
            HStack(spacing: Spacing.sm) {
                if step > 0 && enabled { stepButton("minus") { onStep(-step) } }
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(BrandFont.mono(18, weight: .medium))
                    .foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary)
                    .multilineTextAlignment((step > 0 && enabled) ? .center : .leading)
                    .disabled(!enabled)
                if !unit.isEmpty {
                    Text(unit).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                if step > 0 && enabled { stepButton("plus") { onStep(step) } }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 48)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(theme.elevated))
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
                .tint(theme.accentCrypto.first ?? theme.accent)
            HStack(spacing: Spacing.sm) {
                ForEach(stops, id: \.self) { s in
                    Button { fraction = s } label: {
                        Text("\(Int(s * 100))%")
                            .font(BrandFont.caption.weight(.semibold))
                            .foregroundStyle(isOn(s) ? .white : theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background {
                                if isOn(s) { Capsule().fill(theme.cryptoGradient) }
                                else { Capsule().fill(theme.elevated) }
                            }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }
}

/// The large green (buy) / red (sell) action button used in the asset detail and the order ticket.
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
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(BrandFont.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(color.bestOnColor)
            .background(color)
            .opacity(isEnabled && !isLoading ? 1 : 0.45)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
    }
}
