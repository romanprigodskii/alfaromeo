import SwiftUI

/// Отчёты и экспорт (§9.4): real PDF/CSV statements over a chosen period, handed to the system share
/// sheet (открыть / сохранить в Файлы / отправить). Operations come from ``HistoryStore`` so manually
/// added expenses are included; nothing depends on a backend.
struct ReportsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var period: Period = .thisMonth
    @State private var sharePayload: SharePayload?
    @State private var lastExport: (format: String, count: Int, url: URL)?

    enum Period: String, CaseIterable, Identifiable {
        case thisMonth, lastMonth, quarter, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .thisMonth: return "Этот месяц"
            case .lastMonth: return "Прошлый месяц"
            case .quarter:   return "Квартал"
            case .all:       return "Всё время"
            }
        }

        /// The half-open interval the period selects, relative to the feed's «now» (newest operation),
        /// so it lines up with the future-dated demo timeline. `nil` = всё время.
        func interval(reference: Date) -> DateInterval? {
            let cal = HistoryFormatting.calendar
            switch self {
            case .all:       return nil
            case .thisMonth: return cal.dateInterval(of: .month, for: reference)
            case .lastMonth:
                guard let prev = cal.date(byAdding: .month, value: -1, to: reference) else { return nil }
                return cal.dateInterval(of: .month, for: prev)
            case .quarter:
                guard let start = cal.date(byAdding: .month, value: -3, to: reference) else { return nil }
                return DateInterval(start: start, end: reference)
            }
        }
    }

    private var profileId: String { session.activeProfile?.id ?? "" }

    private var periodTransactions: [Transaction] {
        let all = store.allTransactions
        guard let interval = period.interval(reference: store.referenceDate ?? Date()) else { return all }
        return all.filter { HistoryFormatting.date($0.createdAt).map { interval.contains($0) } ?? false }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Период")
                    Picker("Период", selection: $period) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Выписка по операциям активного профиля: \(HistoryFormatting.operations(periodTransactions.count)).")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }

                VStack(spacing: Spacing.sm) {
                    PrimaryButton(title: "Экспорт в PDF") { exportPDF() }
                        .disabled(periodTransactions.isEmpty)
                    SecondaryButton(title: "Экспорт в CSV") { exportCSV() }
                        .disabled(periodTransactions.isEmpty)
                }

                if let lastExport {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle").foregroundStyle(theme.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(lastExport.format) сформирован")
                                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            Text("\(HistoryFormatting.operations(lastExport.count)), \(period.title.lowercased())")
                                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Button("Отправить") { sharePayload = SharePayload(url: lastExport.url) }
                            .font(BrandFont.subheadline.weight(.medium))
                            .foregroundStyle(theme.accent)
                            .accessibilityLabel("Поделиться снова")
                    }
                    .padding(.horizontal, Spacing.md)
                }

                Text("Файлы формируются на устройстве и открываются в системном окне «Поделиться».")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Отчёты и экспорт")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(reduceMotion ? nil : Motion.snappy, value: lastExport?.format)
        .onChange(of: period) { _, _ in lastExport = nil }
        .sheet(item: $sharePayload) { payload in
            #if canImport(UIKit)
            ShareSheet(items: [payload.url])
            #endif
        }
        .task { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Export

    private func rows() -> [HistoryDocuments.StatementRow] {
        periodTransactions
            .map { tx in
                HistoryDocuments.StatementRow(
                    id: tx.id,
                    date: HistoryFormatting.date(tx.createdAt),
                    counterparty: tx.counterparty ?? store.category(for: tx).title,
                    category: store.category(for: tx).title,
                    amount: tx.amount,
                    currency: tx.currency,
                    status: statusLabel(tx.status)
                )
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private func exportPDF() {
        let r = rows()
        if let url = HistoryDocuments.statementPDF(periodLabel: period.title, rows: r) {
            lastExport = ("PDF", r.count, url)
            sharePayload = SharePayload(url: url)
        }
    }

    private func exportCSV() {
        let r = rows()
        if let url = HistoryDocuments.statementCSV(periodLabel: period.title, rows: r) {
            lastExport = ("CSV", r.count, url)
            sharePayload = SharePayload(url: url)
        }
    }

    private func statusLabel(_ status: TransactionStatus) -> String {
        switch status {
        case .completed:         return "Выполнено"
        case .processing:        return "Обработка"
        case .pending:           return "В ожидании"
        case .failed, .declined: return "Отклонено"
        }
    }
}

#Preview {
    NavigationStack { ReportsView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
