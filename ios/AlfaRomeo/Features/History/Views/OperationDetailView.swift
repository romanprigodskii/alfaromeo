import SwiftUI

/// Деталь операции (§9.4): мерчант, редактируемая категория, чек, «оспорить», «спросить у AI».
///
/// The AI ask and dispute are demo stubs (real AI lands in Фаза 3, §10.9); the editable category and
/// receipt are session-local since the `Transaction` contract carries neither field yet — all clearly
/// labeled. Loads the active profile's operations and resolves `txId` (§5.3).
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
                VStack(spacing: Spacing.lg) {
                    header(tx)
                    detailsCard(tx)
                    if ticket != nil { ticketCard }
                    receiptCard(tx)
                    actions(tx)
                }
                .padding(Spacing.lg)
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
            Text("Создадим обращение по операции — его статус появится здесь и в разделе «Обращения».")
        }
        // Re-scope on BOTH the operation id and the active profile: switching between two
        // personal-type profiles keeps this NavigationStack alive, so watching txId alone would
        // strand the previous profile's operation here (§5.3).
        .task(id: "\(txId)|\(profileId)") { await load() }
    }

    // MARK: - Sections

    private func header(_ tx: Transaction) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: category.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(category.tint)
                .frame(width: 64, height: 64)
                .background(category.tint.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            AmountText(amount: tx.amount, currency: tx.currencySymbol, size: 34,
                       showsSign: true, colorBySign: true)
            Text(tx.counterparty ?? category.title)
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            statusPill(tx.status)
            if ticket != nil {
                StatusPill(status: .warning, text: "Оспаривается")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    private func detailsCard(_ tx: Transaction) -> some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                Button { showCategoryPicker = true } label: {
                    ListRow(icon: category.icon, iconTint: category.tint, title: "Категория",
                            subtitle: "Можно изменить", value: category.title, showsChevron: true)
                }
                .buttonStyle(.plain)
                divider
                detailRow(icon: "calendar", title: "Дата и время", value: dateString(tx))
                divider
                detailRow(icon: "arrow.left.arrow.right", title: "Тип операции", value: kindLabel(tx.kind))
                divider
                detailRow(icon: "creditcard", title: "Счёт", value: accountLabel(tx))
                if let fee = tx.fee, fee > 0 {
                    divider
                    detailRow(icon: "percent", title: "Комиссия", value: rub(fee, currency: tx.currencySymbol))
                }
                if let rate = tx.fxRate {
                    divider
                    detailRow(icon: "function", title: "Курс", value: rub(rate, currency: "₽"))
                }
                divider
                detailRow(icon: "number", title: "ID операции", value: tx.id)
            }
        }
    }

    private func receiptCard(_ tx: Transaction) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.text.fill").foregroundStyle(theme.accent)
                    Text("Чек").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }
                HStack {
                    Text(tx.counterparty ?? "Операция").font(BrandFont.callout)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    AmountText(amount: tx.amount, currency: tx.currencySymbol, size: 15,
                               showsSign: true, colorBySign: true)
                }
                SecondaryButton(title: "Открыть чек (PDF)", icon: "arrow.down.doc") { shareReceipt(tx) }
                Text("PDF-чек формируется на устройстве — можно открыть, сохранить в Файлы или отправить.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func actions(_ tx: Transaction) -> some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Спросить у AI", icon: "sparkles") {
                shell.showCopilot(.operation(
                    id: tx.id,
                    title: tx.counterparty ?? category.title,
                    amount: rub(abs(tx.amount), currency: tx.currencySymbol)))
            }
            SecondaryButton(title: ticket == nil ? "Оспорить операцию" : "Операция оспаривается",
                            icon: "exclamationmark.bubble") {
                showDisputeConfirm = true
            }
            .disabled(ticket != nil)
        }
    }

    /// Dispute ticket summary shown once an operation is contested (§9.4). Carries the case number that
    /// «Обращения» (§9.5) will track — see ``DisputeTicket``.
    @ViewBuilder private var ticketCard: some View {
        if let ticket {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.bubble.fill").foregroundStyle(theme.success)
                        Text(ticket.status.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Spacer()
                        StatusPill(status: .processing, text: ticket.id)
                    }
                    Text("Обращение по операции принято. Отследить и продолжить переписку можно в разделе «Обращения» (Чаты).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Операция не найдена").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, она относится к другому профилю.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }

    // MARK: - Pieces

    private var divider: some View { Divider().overlay(theme.border) }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        ListRow(icon: icon, title: title, value: value)
    }

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
              let account = accounts.first(where: { $0.id == id }) else { return "—" }
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

    private func rub(_ value: Double, currency: String) -> String {
        let n = Self.formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(n) \(currency)"
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

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
