import SwiftUI

/// One operation in the feed: category icon chip · merchant + category/time · signed amount + status.
/// Mirrors the look of the DS `ListRow` (36×36 tinted chip, same type ramp) but carries a custom
/// trailing stack (colored amount over an optional status pill).
struct TransactionRow: View {
    let transaction: Transaction
    let category: CategoryRef

    @Environment(\.theme) private var theme

    private var title: String {
        transaction.counterparty?.isEmpty == false ? transaction.counterparty! : category.title
    }

    private var subtitle: String {
        let time = HistoryFormatting.date(transaction.createdAt).map(HistoryFormatting.time) ?? ""
        return time.isEmpty ? category.title : "\(category.title) · \(time)"
    }

    private var pillStatus: StatusPill.Status? {
        switch transaction.status {
        case .completed:               return nil
        case .processing, .pending:    return .processing
        case .failed, .declined:       return .declined
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(category.tint)
                .frame(width: 36, height: 36)
                .background(category.tint.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandFont.bodyM.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                AmountText(amount: transaction.amount, currency: transaction.currencySymbol,
                           size: 16, showsSign: true, colorBySign: true)
                if let pillStatus {
                    StatusPill(status: pillStatus,
                               text: pillStatus == .declined ? "Отклонено" : "Обработка")
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }
}

/// Render RUB as the «₽» glyph; other currencies (e.g. USDT) keep their ticker.
extension Transaction {
    var currencySymbol: String { currency == "RUB" ? "₽" : currency }
}

#Preview {
    let txs = [
        Transaction(id: "a", profileId: "p", kind: .payment, status: .completed, amount: -1_240.5,
                    currency: "RUB", counterparty: "Пятёрочка", fee: 0, fxRate: nil, createdAt: "2035-06-01T09:14:00Z"),
        Transaction(id: "b", profileId: "p", kind: .payout, status: .completed, amount: 210_000,
                    currency: "RUB", counterparty: "Зарплата", fee: 0, fxRate: nil, createdAt: "2035-05-25T10:00:00Z"),
        Transaction(id: "c", profileId: "p", kind: .payment, status: .declined, amount: -2_599,
                    currency: "RUB", counterparty: "Steam", fee: 0, fxRate: nil, createdAt: "2035-05-24T21:10:00Z"),
    ]
    return VStack(spacing: 0) {
        ForEach(txs) { tx in
            TransactionRow(transaction: tx, category: CategoryRef(TransactionCategory.classify(tx)))
            Divider().overlay(Theme.default.border)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
