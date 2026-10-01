import SwiftUI

/// One operation in the feed: monochrome category glyph, merchant over category and time, signed
/// amount over an optional status pill. Same metrics as the DS `ListRow` (36pt glyph circle, body 17,
/// subheadline 15) so it sits in a ``GroupedSection`` with the hairline inset to the text column.
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
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: category.icon, size: ListRow.glyphSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                AmountText(amount: transaction.amount, currency: transaction.currencySymbol,
                           size: 17, showsSign: true, colorBySign: true)
                if let pillStatus {
                    StatusPill(status: pillStatus,
                               text: pillStatus == .declined ? "Отклонено" : "Обработка")
                }
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
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
    return GroupedSection {
        ForEach(txs) { tx in
            TransactionRow(transaction: tx, category: CategoryRef(TransactionCategory.classify(tx)))
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
