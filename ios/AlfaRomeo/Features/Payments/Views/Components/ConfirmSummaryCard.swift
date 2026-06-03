import SwiftUI

/// The «Подтверждение» summary (§9.2): получатель, крупная сумма, комиссия, ₽-эквивалент (для
/// крипты — по мок-курсу), счёт-источник и итог к списанию. Pure presentation — the flow passes
/// already-computed values.
struct ConfirmSummaryCard: View {
    let recipient: Recipient
    let amount: Double
    let amountSymbol: String
    let fee: Double
    var feeLabel: String = "Комиссия"
    let rubEquivalent: Double?       // crypto only
    let sourceTitle: String
    let sourceSubtitle: String
    let totalText: String?           // fiat total (amount + fee); nil for crypto

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.md) {
            recipientHeader

            AmountText(amount: amount, currency: amountSymbol, size: 40)
                .padding(.vertical, Spacing.xs)

            if let rubEquivalent {
                Text("≈ \(Self.rub(rubEquivalent)) по курсу")
                    .font(BrandFont.callout)
                    .foregroundStyle(theme.textSecondary)
            }

            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    detailRow(icon: "creditcard", title: "Счёт списания", value: sourceTitle, sub: sourceSubtitle)
                    Divider().overlay(theme.border)
                    detailRow(icon: "percent", title: feeLabel,
                              value: fee == 0 ? "Без комиссии" : Self.rub(fee))
                    if let totalText {
                        Divider().overlay(theme.border)
                        detailRow(icon: "sum", title: "Итого к списанию", value: totalText, emphasized: true)
                    }
                }
            }
        }
    }

    private var recipientHeader: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.14)).frame(width: 48, height: 48)
                Image(systemName: recipient.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(recipient.detail).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if let bank = recipient.bank {
                Badge(kind: .text(bank), tint: theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(icon: String, title: String, value: String,
                           sub: String? = nil, emphasized: Bool = false) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                if let sub { Text(sub).font(BrandFont.micro).foregroundStyle(theme.textSecondary) }
            }
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(emphasized ? BrandFont.headline : BrandFont.callout.weight(.medium))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }

    private static func rub(_ value: Double) -> String {
        (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " ₽"
    }
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 0
        return f
    }()
}

#Preview {
    ScrollView {
        ConfirmSummaryCard(
            recipient: Recipient(name: "Иван Петров", detail: "+7 916 200-11-22", icon: "person.fill", bank: "Альфа-Ромео"),
            amount: 5000, amountSymbol: "₽", fee: 0, rubEquivalent: nil,
            sourceTitle: "Текущий счёт", sourceSubtitle: "·· 4921 · RUB", totalText: "5 000 ₽"
        )
        .padding(Spacing.lg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
