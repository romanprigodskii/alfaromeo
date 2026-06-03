import SwiftUI

/// «Выписка» по бизнес-счетам (§8.2 «выписки»): the real `transactions` slice of the business profile,
/// with поступления/списания totals and a one-tap **PDF / CSV** export — reusing the production document
/// generators (``HistoryDocuments``) and the system share sheet (``ShareSheet``) the personal История
/// already ships, so this is assembly, not new plumbing.
struct BusinessStatementsView: View {
    @Environment(\.theme) private var theme
    @State private var store = BusinessAccountsStore.shared
    @State private var share: SharePayload?

    private let periodLabel = "Все операции"

    var body: some View {
        let ops = store.operations
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summaryCard(ops)
                exportRow(ops)
                operationsList(ops)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Выписка")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $share) { payload in
            #if canImport(UIKit)
            ShareSheet(items: [payload.url])
            #endif
        }
    }

    // MARK: Summary

    private func summaryCard(_ ops: [Transaction]) -> some View {
        // Aggregate in ₽ via the store's live valuation so the totals stay correct even if a non-₽
        // operation (валютный / трежери счёт) enters the feed — the per-row amounts keep their native
        // currency, but «Поступления / Списания / Итого» are a single ₽-equivalent figure.
        let income = ops.filter { $0.amount > 0 }.reduce(0) { $0 + rubValue($1) }
        let expense = ops.filter { $0.amount < 0 }.reduce(0) { $0 + abs(rubValue($1)) }
        return SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Выписка по счетам").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("\(store.businessName) · \(periodLabel) · \(ops.count) операций")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "doc.text.fill").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                HStack {
                    flow(title: "Поступления", value: income, tint: theme.success)
                    Spacer()
                    flow(title: "Списания", value: -expense, tint: theme.danger)
                    Spacer()
                    flow(title: "Итого", value: income - expense, tint: theme.textPrimary)
                }
            }
        }
    }

    /// ₽-equivalent of one operation at the store's live rate (₽ ops pass through 1:1).
    private func rubValue(_ tx: Transaction) -> Double { tx.amount * store.rubRate(currency: tx.currency) }

    private func flow(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Text(CryptoFormat.compactRub(value))
                .font(BrandFont.mono(15, weight: .semibold)).foregroundStyle(tint).monospacedDigit()
        }
    }

    // MARK: Export (real PDF / CSV)

    private func exportRow(_ ops: [Transaction]) -> some View {
        HStack(spacing: Spacing.sm) {
            SecondaryButton(title: "PDF", icon: "arrow.down.doc") {
                #if canImport(UIKit)
                if let url = HistoryDocuments.statementPDF(periodLabel: periodLabel, rows: rows(ops)) {
                    share = SharePayload(url: url)
                }
                #endif
            }
            SecondaryButton(title: "CSV", icon: "tablecells") {
                if let url = HistoryDocuments.statementCSV(periodLabel: periodLabel, rows: rows(ops)) {
                    share = SharePayload(url: url)
                }
            }
        }
    }

    private func rows(_ ops: [Transaction]) -> [HistoryDocuments.StatementRow] {
        ops.map { tx in
            HistoryDocuments.StatementRow(
                id: tx.id,
                date: HistoryFormatting.date(tx.createdAt),
                counterparty: tx.counterparty ?? Self.kindLabel(tx.kind),
                category: Self.kindLabel(tx.kind),
                amount: tx.amount,
                currency: tx.currency,
                status: Self.statusLabel(tx.status))
        }
    }

    // MARK: Operations list

    @ViewBuilder private func operationsList(_ ops: [Transaction]) -> some View {
        if ops.isEmpty {
            SurfaceCard {
                Text("По счетам ещё нет операций.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
        } else {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(ops.enumerated()), id: \.element.id) { index, tx in
                        if index > 0 { Divider().overlay(theme.border) }
                        operationRow(tx)
                    }
                }
            }
        }
    }

    private func operationRow(_ tx: Transaction) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.counterparty ?? Self.kindLabel(tx.kind))
                    .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary).lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    Text(dateLabel(tx)).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    StatusPill(status: Self.pillStatus(tx.status))
                        .scaleEffect(0.85, anchor: .leading)
                }
            }
            Spacer(minLength: Spacing.sm)
            AmountText(amount: tx.amount, currency: tx.currency == "RUB" ? "₽" : tx.currency,
                       size: 15, showsSign: true, colorBySign: true)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func dateLabel(_ tx: Transaction) -> String {
        guard let d = HistoryFormatting.date(tx.createdAt) else { return "" }
        return "\(HistoryFormatting.dayMonth(d)), \(HistoryFormatting.time(d))"
    }

    // MARK: Mappers

    private static func kindLabel(_ kind: TransactionKind) -> String {
        switch kind {
        case .transfer: return "Перевод"
        case .payment:  return "Платёж"
        case .convert:  return "Конвертация"
        case .trade:    return "Сделка"
        case .payout:   return "Зачисление"
        case .acquire:  return "Эквайринг"
        }
    }
    private static func statusLabel(_ status: TransactionStatus) -> String {
        switch status {
        case .completed:         return "Выполнено"
        case .processing:        return "Обработка"
        case .pending:           return "В ожидании"
        case .failed, .declined: return "Отклонено"
        }
    }
    private static func pillStatus(_ status: TransactionStatus) -> StatusPill.Status {
        switch status {
        case .completed:         return .success
        case .processing:        return .processing
        case .pending:           return .pending
        case .failed, .declined: return .declined
        }
    }
}
