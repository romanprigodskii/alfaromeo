import SwiftUI

/// Component #7 — a single revenue-feed row (display only, not a button).
/// Leading method icon chip, counterparty + method/time subtitle, trailing signed amount.
struct RevenueEntryRow: View {
    @Environment(\.theme) private var theme
    let entry: RevenueEntry

    private var chipTint: Color {
        entry.wasCrypto ? (theme.accentCrypto.first ?? theme.accent) : theme.accent
    }

    private var subtitle: String {
        var parts = "\(entry.method.title) · \(Self.timeFormatter.string(from: entry.createdAt))"
        if entry.wasCrypto {
            let qty = CryptoFormat.qty(entry.cryptoAmount ?? 0, symbol: entry.cryptoAsset)
            parts += " · \(qty) → ₽"
        }
        return parts
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: entry.method.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(chipTint)
                .frame(width: 36, height: 36)
                .background(
                    chipTint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.counterparty)
                    .font(BrandFont.bodyM.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            AmountText(
                amount: entry.grossRub,
                size: 17,
                showsSign: true,
                colorBySign: true
            )
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()
}

private struct RevenueEntryRow_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            RevenueEntryRow(entry: RevenueEntry(
                id: "1",
                method: .sbp,
                grossRub: 12_400,
                counterparty: "ООО «Светлый путь»",
                createdAt: Date(),
                cryptoAsset: nil,
                cryptoAmount: nil
            ))
            RevenueEntryRow(entry: RevenueEntry(
                id: "2",
                method: .crypto,
                grossRub: 89_300,
                counterparty: "Артур Караманов",
                createdAt: Date().addingTimeInterval(-3_600),
                cryptoAsset: "USDT",
                cryptoAmount: 1_010.42
            ))
            RevenueEntryRow(entry: RevenueEntry(
                id: "3",
                method: .card,
                grossRub: 3_200,
                counterparty: "Розничная продажа",
                createdAt: Date().addingTimeInterval(-7_200),
                cryptoAsset: nil,
                cryptoAmount: nil
            ))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}

#Preview {
    RevenueEntryRow_PreviewHost()
}
