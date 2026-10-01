import SwiftUI

/// Карта (детейл) — single-card management (§6.3). Replaces the 1.0 cross-module stub.
///
/// Крупная карта, баланс, Пополнить/Перевести, кэшбек, история операций, заморозка/разморозка,
/// реквизиты, лимиты, смена дизайна/PIN, перевыпуск, привязка к счёту/активу, Apple Pay и
/// Alfa-Pay-стикер, состояния (заморожена / в доставке / истекла / сожжена).
struct CardDetailView: View {
    let cardId: String

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = CardsStore.shared

    @State private var revealed = false
    @State private var sheet: DetailSheet?
    @State private var toast: String?

    private enum DetailSheet: Int, Identifiable {
        case limits, design, rebind, pin, topUp, transfer
        var id: Int { rawValue }
    }

    private var card: CardItem? { store.routedCard(id: cardId) }
    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var ent: Entitlements { Entitlements.make(for: effectiveTier) }

    var body: some View {
        Group {
            if let card {
                content(card)
            } else {
                emptyState
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(card.map { "\($0.typeLabel) •• \($0.last4)" } ?? "Карта")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(api: api, profileId: profileId) }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $sheet) { which in sheetContent(which) }
    }

    // MARK: Content

    private func content(_ card: CardItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                stateBanner(card)
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    CardFaceView(card: card).frame(maxWidth: 360).frame(maxWidth: .infinity)
                    balanceBlock(card)
                }
                quickActions(card)
                if card.state == .active || card.state == .frozen {
                    CardRequisitesCard(card: card, revealed: $revealed)
                }
                manageSection(card)
                if let burner = card.burner { burnerSection(card, burner) }
                historySection(card)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(reduceMotion ? nil : Motion.snappy, value: card)
        .animation(reduceMotion ? nil : Motion.snappy, value: revealed)
    }

    // MARK: State banner

    @ViewBuilder
    private func stateBanner(_ card: CardItem) -> some View {
        switch card.state {
        case .frozen:
            banner("snowflake", "Карта заморожена", "Операции приостановлены. Разморозьте, чтобы платить.",
                   actionTitle: "Разморозить") {
                store.setFrozen(false, cardId: card.id); flash("Карта разморожена")
            }
        case .shipping, .issuing:
            banner("shippingbox", "Карта в доставке", "Отслеживайте статус и активируйте по прибытии.",
                   actionTitle: "Отследить") {
                if let order = store.orders.first(where: { $0.cardId == card.id }) {
                    router.push(CardsRoute.tracking(orderId: order.id))
                }
            }
        case .expired:
            banner("calendar", "Срок карты истёк", "Перевыпустите карту с новым номером.",
                   actionTitle: "Перевыпустить") {
                store.reissue(cardId: card.id); flash("Карта перевыпущена")
            }
        case .burned:
            banner("flame", "Одноразовая карта сожжена", "Токен использован и больше недоступен.",
                   tint: theme.danger, actionTitle: nil, action: nil)
        case .active:
            EmptyView()
        }
    }

    // MARK: Balance

    @ViewBuilder
    private func balanceBlock(_ card: CardItem) -> some View {
        let accrued = card.limits.monthlySpent * cashbackRate
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(card.type == .crypto ? "Крипто-баланс" : "Доступно на счёте")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            if card.type == .crypto, let wallet = store.wallet(asset: card.assetLink) {
                AmountText(amount: wallet.balance, currency: wallet.asset, size: 40, splitsKopecks: true)
            } else if let account = store.account(id: card.accountId) {
                AmountText(amount: account.balance, currency: MoneyFormat.symbol(for: account.currency),
                           size: 40, splitsKopecks: true)
            } else {
                AmountText(amount: 0, size: 40, splitsKopecks: true)
            }
            Text("Кэшбек за месяц: \(MoneyFormat.fiat(accrued)) (\(ent.cashback.label.lowercased()))")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if card.isDefault {
                Text("Основная карта").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            } else if card.state == .active && !card.isBurner {
                TertiaryButton("Сделать основной") {
                    store.setDefault(cardId: card.id); flash("Карта по умолчанию обновлена")
                }
                .padding(.top, Spacing.xxs)
            }
        }
    }

    private var cashbackRate: Double {
        switch ent.cashback {
        case .basic:  return 0.01
        case .raised: return 0.03
        case .max:    return 0.05
        }
    }

    // MARK: Quick actions (Пополнить / Перевести / Заморозить / Реквизиты)

    private func quickActions(_ card: CardItem) -> some View {
        // Crypto cards display the wallet balance and are funded via conversion (a separate module),
        // so fiat пополнить/перевести on the linked account would contradict the shown balance.
        let moneyDisabled = card.isInactive || card.type == .crypto || store.account(id: card.accountId) == nil
        let frozen = card.state == .frozen
        let manageable = card.state == .active || frozen
        return QuickActionRow {
            QuickActionButton("Пополнить", systemImage: "plus") { sheet = .topUp }
                .disabled(moneyDisabled)
            QuickActionButton("Перевести", systemImage: "arrow.up.right") { sheet = .transfer }
                .disabled(moneyDisabled)
            QuickActionButton(frozen ? "Разморозить" : "Заморозить",
                              systemImage: frozen ? "sun.max" : "snowflake") {
                store.setFrozen(!frozen, cardId: card.id)
                flash(frozen ? "Карта разморожена" : "Карта заморожена")
            }
            .disabled(!manageable)
            QuickActionButton("Реквизиты", systemImage: revealed ? "eye.slash" : "eye") {
                withAnimation(Motion.snappy) { revealed.toggle() }
            }
            .disabled(!manageable)
        }
    }

    // MARK: Management

    private func manageSection(_ card: CardItem) -> some View {
        let manageable = card.state == .active || card.state == .frozen
        let reissueDisabled = card.isBurner || card.state == .shipping
            || card.state == .issuing || card.state == .burned
        return GroupedSection("Управление") {
            if manageable { limitsRow(card) }
            manageRow("paintbrush", "Дизайн карты", disabled: card.isBurner || !manageable) { sheet = .design }
            manageRow("number", "Сменить PIN", disabled: card.isBurner || !manageable) { sheet = .pin }
            manageRow("arrow.triangle.2.circlepath", "Перевыпустить", disabled: reissueDisabled) {
                store.reissue(cardId: card.id); flash("Карта перевыпущена")
            }
            manageRow("link", card.type == .crypto ? "Привязка к активу" : "Привязка к счёту",
                      disabled: card.isBurner || !manageable) { sheet = .rebind }
            if card.addedToWallet {
                ListRow(icon: "wallet.pass", title: "Apple Pay", value: "Добавлена")
            } else {
                manageRow("wallet.pass", "Добавить в Apple Pay", disabled: !manageable) {
                    store.addToWallet(cardId: card.id); flash("Добавлено в Apple Pay")
                }
            }
            manageRow("dot.radiowaves.left.and.right", "Стикер Alfa-Pay", disabled: !manageable) {
                flash("Alfa-Pay-стикер заказан")
            }
        }
    }

    private func manageRow(_ icon: String, _ title: String, disabled: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, showsChevron: !disabled)
        }
        .buttonStyle(.row)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func limitsRow(_ card: CardItem) -> some View {
        Button { sheet = .limits } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ListRow(icon: "slider.horizontal.3", title: "Лимиты",
                        subtitle: "Потрачено \(MoneyFormat.fiat(card.limits.monthlySpent)) из \(MoneyFormat.fiat(card.limits.monthly))",
                        showsChevron: true)
                ProgressBar(value: card.limits.monthlyProgress)
                    .padding(.leading, 48)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .buttonStyle(.row)
    }

    // MARK: Burner

    private func burnerSection(_ card: CardItem, _ burner: BurnerConfig) -> some View {
        GroupedSection("Одноразовая карта") {
            ListRow(icon: "flame", title: burner.statusLabel,
                    subtitle: "\(burner.mode.detail). Лимит \(MoneyFormat.fiat(burner.limit)).")
            if card.state == .active {
                Button { store.burn(cardId: card.id); flash("Карта сожжена") } label: {
                    ListRow(icon: "flame", iconTint: theme.danger, title: "Сжечь карту")
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: History (вход)

    @ViewBuilder
    private func historySection(_ card: CardItem) -> some View {
        let ops = Array(store.operations(for: card).prefix(6))
        if ops.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Последние операции")
                Text("По карте пока нет операций.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
        } else {
            GroupedSection("Последние операции") {
                ForEach(ops) { tx in
                    HStack(spacing: Spacing.sm) {
                        ListRow(icon: txIcon(tx.kind), title: tx.counterparty ?? tx.kind.rawValue,
                                subtitle: txStatus(tx.status))
                        AmountText(amount: tx.amount, size: 17, showsSign: true, colorBySign: true)
                    }
                }
            }
        }
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ which: DetailSheet) -> some View {
        if let card {
            switch which {
            case .limits:
                CardLimitsSheet(initial: card.limits) { store.setLimits($0, cardId: card.id); flash("Лимиты обновлены") }
                    .environment(\.theme, theme)
            case .design:
                CardDesignPickerSheet(card: card,
                                      options: CardDesign.redesignOptions(for: card.type, tier: effectiveTier)) {
                    store.changeDesign($0, cardId: card.id); flash("Дизайн изменён")
                }.environment(\.theme, theme)
            case .rebind:
                CardRebindSheet(card: card, accounts: store.accounts, wallets: store.wallets) { accountId, asset in
                    store.rebind(accountId: accountId, asset: asset, cardId: card.id); flash("Привязка обновлена")
                }.environment(\.theme, theme)
            case .pin:
                CardPinSheet { flash("PIN изменён") }.environment(\.theme, theme)
            case .topUp:
                if let account = store.account(id: card.accountId) {
                    QuickMoveSheet(kind: .topUp, account: account) { store.topUp($0, accountId: account.id) }
                        .environment(\.theme, theme)
                }
            case .transfer:
                if let account = store.account(id: card.accountId) {
                    QuickMoveSheet(kind: .transfer, account: account) { store.transfer($0, accountId: account.id) }
                        .environment(\.theme, theme)
                }
            }
        }
    }

    // MARK: Bits

    /// State notice: a neutral surface with a monochrome glyph (danger only for a burned card) and an
    /// accent text action. No tinted banner backgrounds.
    private func banner(_ icon: String, _ title: String, _ message: String, tint: Color? = nil,
                        actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm + 4) {
            GlyphCircle(systemImage: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(message).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    TertiaryButton(actionTitle, action: action).padding(.top, Spacing.xs)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            StatusPill(status: .success, text: toast)
                .padding(.bottom, Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled { withAnimation(Motion.smooth) { self.toast = nil } }
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            GlyphCircle(systemImage: "creditcard", size: 56)
            Text("Карта не найдена").font(BrandFont.title2).foregroundStyle(theme.textPrimary)
            PrimaryButton(title: "Заказать карту") { router.push(CardsRoute.order) }
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.screen)
    }

    private func flash(_ text: String) { withAnimation(Motion.smooth) { toast = text } }

    private func txIcon(_ kind: TransactionKind) -> String {
        switch kind {
        case .transfer: return "arrow.left.arrow.right"
        case .payment:  return "cart"
        case .convert:  return "arrow.2.squarepath"
        case .trade:    return "chart.line.uptrend.xyaxis"
        case .payout:   return "arrow.down.circle"
        case .acquire:  return "qrcode"
        }
    }

    private func txStatus(_ status: TransactionStatus) -> String {
        switch status {
        case .pending:    return "В ожидании"
        case .processing: return "Обработка"
        case .completed:  return "Выполнено"
        case .failed:     return "Ошибка"
        case .declined:   return "Отклонено"
        }
    }
}
