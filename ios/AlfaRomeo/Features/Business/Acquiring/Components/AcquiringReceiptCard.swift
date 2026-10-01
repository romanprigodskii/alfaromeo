import SwiftUI

/// Component #6 — чек об успешном эквайринг-платеже.
struct AcquiringReceiptCard: View {
    let receipt: AcquiringReceipt

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                detailList
                totalBlock
                footer
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Чек \(receipt.receiptNo)")
                    .font(BrandFont.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Оплата принята")
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            StatusPill(status: .success, text: "Зачислено")
        }
    }

    // MARK: Details

    private var detailList: some View {
        VStack(spacing: Spacing.sm) {
            detailRow(label: "Способ", value: receipt.method.title)
            divider

            if receipt.wasCrypto {
                detailRow(
                    label: "Оплачено",
                    value: CryptoFormat.qty(receipt.grossAmount, symbol: receipt.payCurrency)
                )
                divider
                detailRow(
                    label: "Live-курс",
                    value: "1 \(receipt.cryptoAsset ?? receipt.payCurrency) = \(CryptoFormat.rub(receipt.liveRate ?? 0, fraction: 2))"
                )
            } else {
                detailRow(label: "Оплачено", value: CryptoFormat.rub(receipt.grossAmount))
            }
            divider

            detailRow(label: "Комиссия", value: feeValue, hint: feeHint)
        }
    }

    private func detailRow(label: String, value: String, hint: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(BrandFont.callout.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.trailing)
                if let hint {
                    Text(hint)
                        .font(BrandFont.micro)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private var divider: some View {
        Divider().overlay(theme.border)
    }

    private var feeValue: String {
        receipt.feeRub <= 0
            ? "Без комиссии"
            : "\u{2212}\(CryptoFormat.rub(receipt.feeRub, fraction: 2))"
    }

    private var feeHint: String? {
        receipt.feeRub <= 0 ? nil : receipt.method.feeLabel
    }

    // MARK: Total

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Зачислено на счёт")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
            AmountText(amount: receipt.creditedRub, size: 24, colorBySign: false)
                .foregroundStyle(theme.success)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        Text(Self.timeFormatter.string(from: receipt.createdAt))
            .font(BrandFont.micro)
            .foregroundStyle(theme.textSecondary)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm, dd.MM"
        return f
    }()
}

// MARK: - Preview

private struct AcquiringReceiptCard_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            AcquiringReceiptCard(
                receipt: AcquiringReceipt(
                    id: "r1",
                    receiptNo: "A-2035-0481",
                    method: .card,
                    grossAmount: 14_900,
                    payCurrency: "₽",
                    creditedRub: 14_676.50,
                    feeRub: 223.50,
                    liveRate: nil,
                    cryptoAmount: nil,
                    cryptoAsset: nil,
                    createdAt: Date()
                )
            )

            AcquiringReceiptCard(
                receipt: AcquiringReceipt(
                    id: "r2",
                    receiptNo: "A-2035-0482",
                    method: .crypto,
                    grossAmount: 100,
                    payCurrency: "USDT",
                    creditedRub: 9_801.00,
                    feeRub: 89.10,
                    liveRate: 99.00,
                    cryptoAmount: 100,
                    cryptoAsset: "USDT",
                    createdAt: Date()
                )
            )

            AcquiringReceiptCard(
                receipt: AcquiringReceipt(
                    id: "r3",
                    receiptNo: "A-2035-0483",
                    method: .digitalRuble,
                    grossAmount: 5_000,
                    payCurrency: "₽",
                    creditedRub: 5_000,
                    feeRub: 0,
                    liveRate: nil,
                    cryptoAmount: nil,
                    cryptoAsset: nil,
                    createdAt: Date()
                )
            )
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
    }
}

#Preview {
    AcquiringReceiptCard_PreviewHost()
        .environment(\.theme, .default)
}
