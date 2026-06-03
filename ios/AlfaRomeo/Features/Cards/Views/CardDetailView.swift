import SwiftUI

/// Карта (детейл) — single-card management (§6.3). Replaces the 1.0 cross-module stub.
///
/// Крупная карта (дизайн по типу/тиру) · баланс · ··последние4 · Пополнить/Перевести · кэшбек ·
/// история операций · заморозка/разморозка · реквизиты (глаз) · лимиты · смена дизайна/PIN ·
/// перевыпуск · привязка к счёту/активу · добавление в Apple Pay / Alfa-Pay-стикер · состояния
/// (заморожена / в доставке / истёкла / сожжена).
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
        .navigationTitle(card.map { "\($0.typeLabel) ·· \($0.last4)" } ?? "Карта")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(api: api, profileId: profileId) }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $sheet) { which in sheetContent(which) }
    }

    // MARK: Content

    private func content(_ card: CardItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stateBanner(card)
                CardFaceView(card: card).frame(maxWidth: 360).frame(maxWidth: .infinity)
                balanceBlock(card)
                moneyActions(card)
                cashbackCard(card)
                actionGrid(card)
                if card.state == .active || card.state == .frozen {
                    CardRequisitesCard(card: card, revealed: $revealed)
                    limitsCard(card)
                }
                if let burner = card.burner { burnerCard(card, burner) }
                historySection(card)
            }
            .padding(Spacing.lg)
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
                   tint: BrandColors.cryptoCyan, actionTitle: "Разморозить") {
                store.setFrozen(false, cardId: card.id); flash("Карта разморожена")
            }
        case .shipping, .issuing:
            banner("shippingbox.fill", "Карта в доставке", "Отслеживайте статус и активируйте по прибытии.",
                   tint: theme.accent, actionTitle: "Отследить") {
                if let order = store.orders.first(where: { $0.cardId == card.id }) {
                    router.push(CardsRoute.tracking(orderId: order.id))
                }
            }
        case .expired:
            banner("calendar.badge.exclamationmark", "Срок карты истёк", "Перевыпустите карту с новым номером.",
                   tint: theme.warning, actionTitle: "Перевыпустить") {
                store.reissue(cardId: card.id); flash("Карта перевыпущена")
            }
        case .burned:
            banner("flame.fill", "Одноразовая карта сожжена", "Токен использован и больше недоступен.",
                   tint: theme.danger, actionTitle: nil, action: nil)
        case .active:
            EmptyView()
        }
    }

    // MARK: Balance

    @ViewBuilder
    private func balanceBlock(_ card: CardItem) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(card.type == .crypto ? "Крипто-баланс" : "Доступно на счёте")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                if card.type == .crypto, let wallet = store.wallet(asset: card.assetLink) {
                    AmountText(amount: wallet.balance, currency: wallet.asset, size: 30)
                } else if let account = store.account(id: card.accountId) {
                    AmountText(amount: account.balance, currency: symbol(account.currency), size: 30)
                } else {
                    AmountText(amount: 0, size: 30)
                }
                HStack(spacing: Spacing.sm) {
                    Text("•• \(card.last4)").font(BrandFont.mono(14)).foregroundStyle(theme.textSecondary)
                    if card.isDefault { Badge(kind: .text("Основная"), tint: theme.accent) }
                    Badge(kind: .text(card.typeLabel), tint: theme.textSecondary)
                }
                if !card.isDefault && card.state == .active && !card.isBurner {
                    Button {
                        store.setDefault(cardId: card.id); flash("Карта по умолчанию обновлена")
                    } label: {
                        Label("Сделать основной", systemImage: "star")
                            .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain).padding(.top, 2)
                }
            }
        }
    }

    // MARK: Money actions (Пополнить / Перевести)

    @ViewBuilder
    private func moneyActions(_ card: CardItem) -> some View {
        // Crypto cards display the wallet balance and are funded via conversion (a separate module),
        // so fiat пополнить/перевести on the linked account would contradict the shown balance.
        let disabled = card.isInactive || card.type == .crypto || store.account(id: card.accountId) == nil
        HStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Пополнить", icon: "arrow.down.to.line") { sheet = .topUp }
                .disabled(disabled)
            SecondaryButton(title: "Перевести", icon: "arrow.up.right") { sheet = .transfer }
                .disabled(disabled)
        }
    }

    // MARK: Cashback

    private func cashbackCard(_ card: CardItem) -> some View {
        let accrued = card.limits.monthlySpent * cashbackRate
        return SurfaceCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 40, height: 40)
                    .background(theme.accent.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Кэшбек · \(ent.cashback.label)").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("Накоплено за месяц").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                AmountText(amount: accrued, size: 18)
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

    // MARK: Action grid

    private func actionGrid(_ card: CardItem) -> some View {
        let frozen = card.state == .frozen
        let active = card.state == .active
        let manageable = active || frozen
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
            gridButton(frozen ? "sun.max.fill" : "snowflake", frozen ? "Разморозить" : "Заморозить",
                       disabled: !manageable) {
                store.setFrozen(!frozen, cardId: card.id)
                flash(frozen ? "Карта разморожена" : "Карта заморожена")
            }
            gridButton(revealed ? "eye.slash" : "eye", "Реквизиты", disabled: !manageable) {
                withAnimation(Motion.snappy) { revealed.toggle() }
            }
            gridButton("slider.horizontal.3", "Лимиты", disabled: !manageable) { sheet = .limits }
            gridButton("paintbrush.fill", "Дизайн", disabled: card.isBurner || !manageable) { sheet = .design }
            gridButton("number", "PIN", disabled: card.isBurner || !manageable) { sheet = .pin }
            gridButton("arrow.triangle.2.circlepath", "Перевыпуск",
                       disabled: card.isBurner || card.state == .shipping
                                 || card.state == .issuing || card.state == .burned) {
                store.reissue(cardId: card.id); flash("Карта перевыпущена")
            }
            gridButton("link", card.type == .crypto ? "Актив" : "Счёт", disabled: card.isBurner || !manageable) { sheet = .rebind }
            if card.addedToWallet {
                gridButton("checkmark.seal.fill", "В Apple Pay", tint: theme.success, disabled: true) {}
            } else {
                gridButton("wallet.pass.fill", "Apple Pay", disabled: !manageable) {
                    store.addToWallet(cardId: card.id); flash("Добавлено в Apple Pay")
                }
            }
            gridButton("dot.radiowaves.left.and.right", "Alfa-Pay", disabled: !manageable) {
                flash("Alfa-Pay-стикер заказан")
            }
        }
    }

    private func gridButton(_ icon: String, _ label: String, tint: Color? = nil,
                            disabled: Bool = false, action: @escaping () -> Void) -> some View {
        let base = tint ?? theme.accent
        return Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(disabled ? theme.textSecondary : base)
                    .frame(width: 52, height: 52)
                    .background((disabled ? theme.textSecondary : base).opacity(0.14), in: Circle())
                Text(label).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: Limits preview

    private func limitsCard(_ card: CardItem) -> some View {
        Button { sheet = .limits } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Label("Лимиты", systemImage: "slider.horizontal.3")
                            .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                    ProgressBar(value: card.limits.monthlyProgress)
                    HStack {
                        Text("На операцию: \(Int(card.limits.perTransaction)) ₽")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text("В месяц: \(Int(card.limits.monthly)) ₽")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }.buttonStyle(.plain)
    }

    // MARK: Burner

    private func burnerCard(_ card: CardItem, _ burner: BurnerConfig) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(burner.statusLabel, systemImage: "flame")
                    .font(BrandFont.headline).foregroundStyle(theme.warning)
                Text("\(burner.mode.detail). Лимит \(Int(burner.limit)) ₽.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                if card.state == .active {
                    SecondaryButton(title: "Сжечь карту", icon: "flame.fill") {
                        store.burn(cardId: card.id); flash("Карта сожжена")
                    }
                }
            }
        }
    }

    // MARK: History (вход)

    private func historySection(_ card: CardItem) -> some View {
        let ops = Array(store.operations(for: card).prefix(6))
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Последние операции").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            if ops.isEmpty {
                Text("Пока нет операций по карте.").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            } else {
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(ops.enumerated()), id: \.element.id) { i, tx in
                            HStack {
                                ListRow(icon: txIcon(tx.kind), title: tx.counterparty ?? tx.kind.rawValue,
                                        subtitle: txStatus(tx.status))
                                AmountText(amount: tx.amount, size: 15, showsSign: true, colorBySign: true)
                            }
                            if i < ops.count - 1 { Divider().overlay(theme.border) }
                        }
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

    @ViewBuilder
    private func banner(_ icon: String, _ title: String, _ message: String, tint: Color,
                        actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(message).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle).font(BrandFont.callout.weight(.semibold)).foregroundStyle(tint)
                    }.buttonStyle(.plain).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
            Image(systemName: "creditcard").font(.system(size: 36)).foregroundStyle(theme.textSecondary)
            Text("Карта не найдена").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            PrimaryButton(title: "Заказать карту", icon: "plus") { router.push(CardsRoute.order) }
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }

    private func flash(_ text: String) { withAnimation(Motion.smooth) { toast = text } }

    private func symbol(_ currency: String) -> String { currency == "RUB" ? "₽" : currency }

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
