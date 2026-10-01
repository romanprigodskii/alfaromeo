import SwiftUI

/// Деталь операции (§9.4): мерчант, редактируемая категория, чек, «оспорить», «спросить у AI».
///
/// The editable category and the receipt are session-local since the `Transaction` contract carries
/// neither field yet. Loads the active profile's operations and resolves `txId` (§5.3).
struct OperationDetailView: View {
    let txId: String

    @Environment(AppSession.self) private var session
    @Environment(ShellState.self) private var shell
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var loaded = false
    @State private var showCategoryPicker = false
    @State private var showDisputeConfirm = false
    @State private var sharePayload: SharePayload?

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var tx: Transaction? { store.transaction(id: txId) }
    private var accounts: [Account] { store.accounts }
    /// Resolved category (override / custom / auto) — the single source the chip and the picker share.
    private var category: CategoryRef { tx.map { store.category(for: $0) } ?? CategoryRef(.other) }
    private var ticket: DisputeTicket? { store.ticket(forTx: txId) }

    var body: some View {
        ScrollView {
            if let tx = tx {
                VStack(spacing: Spacing.section) {
                    header(tx)
                    detailsSection(tx)
                    actionsSection(tx)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            } else if loaded {
                notFound
            } else {
                ProgressView().controlSize(.large).tint(theme.accent)
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Операция")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(reduceMotion ? nil : Motion.snappy, value: ticket)
        .sheet(isPresented: $showCategoryPicker) {
            // Selecting a category persists it as an override on this operation (§9.4 «категория
            // редактируемая») — the chip + analytics update live, without touching the contract.
            CategoryPickerSheet(selection: Binding(
                get: { category },
                set: { store.setCategory(txId: txId, ref: $0) }
            ))
        }
        .sheet(item: $sharePayload) { payload in
            #if canImport(UIKit)
            ShareSheet(items: [payload.url])
            #endif
        }
        .confirmationDialog("Оспорить операцию?", isPresented: $showDisputeConfirm, titleVisibility: .visible) {
            Button("Оспорить", role: .destructive) { if let tx = tx { store.dispute(tx, category: category) } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Создадим обращение по операции. Его статус появится здесь и в разделе «Обращения».")
        }
        // Re-scope on BOTH the operation id and the active profile: switching between two
        // personal-type profiles keeps this NavigationStack alive, so watching txId alone would
        // strand the previous profile's operation here (§5.3).
        .task(id: "\(txId)|\(profileId)") { await load() }
    }

    // MARK: - Sections

    private func header(_ tx: Transaction) -> some View {
        VStack(spacing: Spacing.sm) {
            GlyphCircle(systemImage: category.icon, size: 56)
            Text(tx.counterparty ?? category.title)
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
            AmountText(amount: tx.amount, currency: tx.currencySymbol, size: 40,
                       showsSign: true, colorBySign: true, splitsKopecks: true)
            HStack(spacing: Spacing.sm) {
                statusPill(tx.status)
                if ticket != nil {
                    StatusPill(status: .warning, text: "Оспаривается")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    /// Key/value facts as one grouped list. Once the operation is contested the dispute ticket joins
    /// it as a row, and the footer points to «Обращения» (§9.4, §9.5).
    private func detailsSection(_ tx: Transaction) -> some View {
        GroupedSection(footer: ticket == nil ? nil
                       : "Обращение принято. Статус и переписка в разделе «Обращения» в Чатах.") {
            Button { showCategoryPicker = true } label: {
                ListRow(title: "Категория", value: category.title, showsChevron: true)
            }
            .buttonStyle(.row)
            ListRow(title: "Дата и время", value: dateString(tx))
            ListRow(title: "Тип операции", value: kindLabel(tx.kind))
            ListRow(title: "Счёт", value: accountLabel(tx))
            if let fee = tx.fee, fee > 0 {
                ListRow(title: "Комиссия", value: MoneyFormat.amount(fee, currency: tx.currencySymbol))
            }
            if let rate = tx.fxRate {
                ListRow(title: "Курс", value: MoneyFormat.fiat(rate))
            }
            ListRow(title: "ID операции", value: tx.id)
            if let ticket {
                ListRow(title: "Обращение", subtitle: ticket.status.title, value: ticket.id)
            }
        }
    }

    /// Receipt, copilot and dispute as one list of actions (no stacked buttons, no sparkles).
    private func actionsSection(_ tx: Transaction) -> some View {
        GroupedSection(footer: "Чек в PDF формируется на устройстве: его можно открыть, сохранить в Файлы или отправить.") {
            Button { shareReceipt(tx) } label: {
                ListRow(icon: "doc.text", title: "Чек в PDF", showsChevron: true)
            }
            .buttonStyle(.row)
            Button {
                shell.showCopilot(.operation(
                    id: tx.id,
                    title: tx.counterparty ?? category.title,
                    amount: MoneyFormat.amount(abs(tx.amount), currency: tx.currencySymbol)))
            } label: {
                ListRow(icon: "text.bubble", title: "Спросить у AI", showsChevron: true)
            }
            .buttonStyle(.row)
            Button { showDisputeConfirm = true } label: {
                ListRow(icon: "exclamationmark.bubble",
                        title: ticket == nil ? "Оспорить операцию" : "Операция оспаривается",
                        showsChevron: ticket == nil)
                    .opacity(ticket == nil ? 1 : 0.5)
            }
            .buttonStyle(.row)
            .disabled(ticket != nil)
        }
    }

    private func shareReceipt(_ tx: Transaction) {
        if let url = HistoryDocuments.receiptPDF(for: tx, categoryTitle: category.title,
                                                 accountTitle: accountLabel(tx)) {
            sharePayload = SharePayload(url: url)
        }
    }

    private var notFound: some View {
        VStack(spacing: Spacing.md) {
            GlyphCircle(systemImage: "questionmark.folder", size: 56)
            Text("Операция не найдена").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, она относится к другому профилю.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }

    // MARK: - Pieces

    private func statusPill(_ status: TransactionStatus) -> some View {
        let mapped: StatusPill.Status
        let text: String
        switch status {
        case .completed:            mapped = .success;    text = "Выполнено"
        case .processing:           mapped = .processing; text = "Обработка"
        case .pending:              mapped = .pending;    text = "В ожидании"
        case .failed, .declined:    mapped = .declined;   text = "Отклонено"
        }
        return StatusPill(status: mapped, text: text)
    }

    // MARK: - Helpers

    private func dateString(_ tx: Transaction) -> String {
        guard let date = HistoryFormatting.date(tx.createdAt) else { return tx.createdAt }
        return "\(HistoryFormatting.dayMonth(date)), \(HistoryFormatting.time(date))"
    }

    private func accountLabel(_ tx: Transaction) -> String {
        guard let id = HistoryFilter.resolvedAccountId(for: tx, in: accounts),
              let account = accounts.first(where: { $0.id == id }) else { return "Не определён" }
        switch account.type {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой ₽"
        }
    }

    private func kindLabel(_ kind: TransactionKind) -> String {
        switch kind {
        case .transfer: return "Перевод"
        case .payment:  return "Платёж"
        case .convert:  return "Конвертация"
        case .trade:    return "Сделка"
        case .payout:   return "Зачисление"
        case .acquire:  return "Эквайринг"
        }
    }

    private func load() async {
        loaded = false
        await store.load(api: api, profileId: profileId)
        loaded = true
    }
}

#Preview {
    NavigationStack {
        OperationDetailView(txId: "t1")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(ShellState())
    .environment(\.theme, .default)
    .environment(\.apiClient, MockAPIClient())
}
