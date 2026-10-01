import SwiftUI

/// Заказ карты (§6.2): a self-contained, multi-step wizard pushed as the single `.order` route:
///
/// `тип → дизайн + привязка → ВИРТУАЛЬНАЯ выпускается мгновенно → (опц.) пластик: адрес → способ →
/// стоимость по тиру → подтверждение → трекинг → активация`. The disposable product branches to an
/// instant burner generator. The tier card-limit is enforced softly with ``UpsellCard`` (Base → блок
/// на 2-й карте; Pro+ → проходит); burners never count against the limit.
struct CardOrderView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = CardsStore.shared

    private enum Step: Hashable {
        case product, design, issued          // virtual path
        case address, method, confirm, tracking // plastic path
        case burner, burnerIssued              // disposable path
    }

    @State private var step: Step = .product
    @State private var draft = CardOrderDraft()
    @State private var issuedCardId: String?
    @State private var orderId: String?
    @State private var revealed = false

    // MARK: Derived

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var ent: Entitlements { Entitlements.make(for: effectiveTier) }
    private var canAddPrimaryNow: Bool { ent.canAddCard(currentCount: store.primaryCards.count) }
    private var issuedCard: CardItem? { issuedCardId.flatMap { store.card(id: $0) } }

    private var recommendedTier: Tier {
        let track = Tier.track(forBusiness: session.isBusinessMode)
        return track[min(effectiveTier.rank + 1, track.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
                    .transition(.opacity)
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Заказ карты")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(api: api, profileId: profileId)
            consumePreset()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                if canGoBack {
                    Button { withAnimation(Motion.smooth) { goBack() } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textPrimary).frame(width: 32, height: 32)
                            .background(theme.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Назад")
                }
                Text(stepTitle).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                Spacer()
            }
            if let sub = stepSubtitle {
                Text(sub).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .product:      productStep
        case .design:       designStep
        case .issued:       issuedStep
        case .address:      addressStep
        case .method:       methodStep
        case .confirm:      confirmStep
        case .tracking:     trackingStep
        case .burner:       burnerStep
        case .burnerIssued: burnerIssuedStep
        }
    }

    // 1 ── Product
    private var productStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if !canAddPrimaryNow {
                UpsellCard(
                    title: "Лимит карт на тарифе \(effectiveTier.shortLabel)",
                    message: "Доступно карт: \(ent.maxCardsLabel). Одноразовую можно выпустить всегда, она не занимает лимит. Для обычной карты повысьте тариф.",
                    recommendedTier: recommendedTier)
            }
            GroupedSection(footer: "Одноразовые карты не занимают лимит тарифа.") {
                ForEach(CardProduct.allCases) { product in
                    selectableRow(
                        icon: product.icon, title: product.title, subtitle: product.subtitle,
                        selected: draft.product == product,
                        locked: !canAddPrimaryNow && product != .disposable
                    ) { draft.product = product }
                }
            }
            PrimaryButton(title: "Далее") { advanceFromProduct() }
                .disabled(draft.product != .disposable && !canAddPrimaryNow)
        }
    }

    // 2 ── Design + binding
    private var designStep: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                SectionHeader("Дизайн")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm + 4) {
                        ForEach(CardDesign.options(for: draft.product, tier: effectiveTier)) { design in
                            designOption(design)
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 3)
                }
                .scrollClipDisabled()
            }

            if draft.product.bindsToCrypto {
                bindingList("Списывать с актива",
                            store.wallets.map { ($0.asset, $0.asset, "\($0.asset) · \($0.chain)",
                                                 MoneyFormat.amount($0.balance, currency: $0.asset)) },
                            selectedId: draft.asset) { draft.asset = $0 }
            } else {
                bindingList("Привязать к счёту",
                            store.accounts.map { ($0.id, $0.currency, accountTitle($0), fiat($0)) },
                            selectedId: draft.accountId) { draft.accountId = $0 }
            }

            PrimaryButton(title: "Выпустить виртуальную карту") { issueVirtual() }
        }
    }

    // 3 ── Virtual issued (instant)
    @ViewBuilder
    private var issuedStep: some View {
        if let card = issuedCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                StatusPill(status: .success, text: "Доступна для оплат")
                CardFaceView(card: card).frame(maxWidth: 300).frame(maxWidth: .infinity)
                CardRequisitesCard(card: card, revealed: $revealed)
                walletButton(card)

                if draft.product.allowsPlastic {
                    if canAddPrimaryNow {
                        PrimaryButton(title: "Заказать пластик") {
                            withAnimation(Motion.smooth) { step = .address }
                        }
                    } else {
                        UpsellCard(
                            title: "Пластик на тарифе выше",
                            message: "На \(effectiveTier.displayName) доступно карт: \(ent.maxCardsLabel). Виртуальная уже у вас, для пластика повысьте тариф.",
                            recommendedTier: recommendedTier)
                    }
                }
                SecondaryButton(title: "Готово") { router.pop() }
            }
        }
    }

    // 4a ── Address
    private var addressStep: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            TextField("Город, улица, дом, квартира", text: $draft.address, axis: .vertical)
                .lineLimit(2...4)
                .font(BrandFont.bodyM)
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            TertiaryButton("Определить по геолокации (демо)") {
                withAnimation(Motion.snappy) { draft.address = "Москва, Пресненская наб., 8, кв. 142" }
            }
            Spacer(minLength: Spacing.lg)
            PrimaryButton(title: "Далее") { withAnimation(Motion.smooth) { step = .method } }
                .disabled(draft.address.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // 4b ── Method (cost by tier)
    private var methodStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GroupedSection(footer: "Стоимость зависит от тарифа: на Pro со скидкой, на Infinite бесплатно.") {
                ForEach(DeliveryMethod.allCases) { method in
                    selectableRow(
                        icon: method.icon, title: method.label,
                        subtitle: method.detail, trailing: method.priceLabel(for: effectiveTier),
                        selected: draft.method == method
                    ) { draft.method = method }
                }
            }
            PrimaryButton(title: "Далее") { withAnimation(Motion.smooth) { step = .confirm } }
        }
    }

    // 4c ── Confirm
    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GroupedSection {
                summaryRow("Карта", CardDesign.design(for: draft.designId).name)
                summaryRow("Доставка", "\(draft.method.label) · \(draft.method.detail)")
                summaryRow("Адрес", draft.address)
                summaryRow("Стоимость", draft.method.priceLabel(for: effectiveTier), emphasised: true)
            }
            PrimaryButton(title: "Подтвердить и заказать") { confirmPlastic() }
        }
    }

    // 5 ── Tracking (reuses the shared content)
    @ViewBuilder
    private var trackingStep: some View {
        if let orderId {
            DeliveryTrackingContent(orderId: orderId) { router.pop() }
        }
    }

    // B1 ── Burner config
    private var burnerStep: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            GroupedSection("Режим") {
                ForEach(BurnerMode.allCases) { mode in
                    selectableRow(icon: mode.icon, title: mode.title, subtitle: mode.detail,
                                  selected: draft.burnerMode == mode) { draft.burnerMode = mode }
                }
            }
            GroupedSection("Параметры") {
                if draft.burnerMode == .merchantLock {
                    TextField("Мерчант, например Steam", text: $draft.burnerMerchant)
                        .font(BrandFont.bodyM)
                        .frame(minHeight: Spacing.rowMinHeight)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Лимит").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Spacer()
                        AmountText(amount: draft.burnerLimit, size: 17)
                    }
                    Slider(value: $draft.burnerLimit, in: 1_000...100_000, step: 1_000).tint(theme.accent)
                }
                .padding(.vertical, Spacing.rowVertical)
            }
            bindingList("Счёт списания",
                        store.accounts.map { ($0.id, $0.currency, accountTitle($0), fiat($0)) },
                        selectedId: draft.accountId ?? store.accounts.first?.id) { draft.accountId = $0 }
            PrimaryButton(title: "Сгенерировать одноразовую") { createBurner() }
                .disabled(draft.burnerMode == .merchantLock && draft.burnerMerchant.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // B2 ── Burner issued
    @ViewBuilder
    private var burnerIssuedStep: some View {
        if let card = issuedCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                StatusPill(status: .success, text: "Одноразовая карта создана")
                CardFaceView(card: card).frame(maxWidth: 300).frame(maxWidth: .infinity)
                CardRequisitesCard(card: card, revealed: $revealed)
                if let burner = card.burner {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(burner.statusLabel).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("Лимит \(MoneyFormat.fiat(burner.limit)). \(burner.mode.detail).")
                            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                SecondaryButton(title: "Готово") { router.pop() }
            }
        }
    }

    // MARK: Reusable bits

    private func walletButton(_ card: CardItem) -> some View {
        Group {
            if card.addedToWallet {
                HStack { Image(systemName: "checkmark.seal.fill"); Text("Добавлена в Apple Pay") }
                    .font(BrandFont.headline).foregroundStyle(theme.success)
                    .frame(maxWidth: .infinity).frame(minHeight: 52)
            } else {
                Button { store.addToWallet(cardId: card.id) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "applelogo"); Text("Добавить в Apple Pay")
                    }
                    .font(BrandFont.headline).foregroundStyle(BrandColors.white)
                    .frame(maxWidth: .infinity).frame(minHeight: 52)
                    .background(BrandColors.black, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }.buttonStyle(PressableButtonStyle())
            }
        }
    }

    /// A selectable list row: monochrome glyph, title, subtitle; trailing lock, price or accent check.
    private func selectableRow(icon: String, title: String, subtitle: String,
                               trailing: String? = nil, selected: Bool, locked: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: { if !locked { withAnimation(Motion.snappy, action) } }) {
            HStack(spacing: Spacing.sm + 4) {
                GlyphCircle(systemImage: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.sm)
                if locked {
                    Image(systemName: "lock").font(.system(size: 15)).foregroundStyle(theme.textTertiary)
                } else {
                    if let trailing {
                        Text(trailing).font(BrandFont.bodyM).monospacedDigit().foregroundStyle(theme.textPrimary)
                    }
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .opacity(selected ? 1 : 0)
                }
            }
            .padding(.vertical, Spacing.sm + 2)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .groupedRowTextInset(48)
            .opacity(locked ? 0.45 : 1)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Design option in the horizontal picker: the card art with an accent ring when selected.
    private func designOption(_ design: CardDesign) -> some View {
        let isSelected = draft.designId == design.id
        return Button { withAnimation(Motion.snappy) { draft.designId = design.id } } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CardFaceView(card: previewCard(design.id))
                    .frame(width: 200)
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2))
                VStack(alignment: .leading, spacing: 0) {
                    Text(design.name).font(BrandFont.subheadline.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(design.blurb).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Account / asset list: (id, currency for the glyph, title, formatted balance).
    private func bindingList(_ title: String, _ items: [(String, String, String, String)], selectedId: String?,
                             onPick: @escaping (String) -> Void) -> some View {
        GroupedSection(title) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button { withAnimation(Motion.snappy) { onPick(item.0) } } label: {
                    CardPickRow(glyph: item.1, title: item.2, subtitle: item.3, selected: selectedId == item.0)
                }
                .buttonStyle(.row)
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(emphasised ? BrandFont.headline : BrandFont.bodyM)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private func fiat(_ a: Account) -> String {
        MoneyFormat.fiat(a.balance, currency: MoneyFormat.symbol(for: a.currency))
    }

    private func previewCard(_ designId: String) -> CardItem {
        CardItem(id: "preview_\(designId)", accountId: "", type: draft.product.cardType,
                 last4: "0000", state: .active, designId: designId, isDefault: false,
                 assetLink: draft.product.bindsToCrypto ? (draft.asset ?? "BTC") : nil)
    }

    private func accountTitle(_ a: Account) -> String {
        switch a.type {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой рубль"
        }
    }

    // MARK: Step machine

    private var canGoBack: Bool {
        switch step {
        case .design, .address, .method, .confirm, .burner: return true
        default: return false
        }
    }

    private func goBack() {
        switch step {
        case .design:  step = .product
        case .address: step = .issued
        case .method:  step = .address
        case .confirm: step = .method
        case .burner:  step = .product
        default: break
        }
    }

    private var stepTitle: String {
        switch step {
        case .product:      return "Тип карты"
        case .design:       return "Дизайн и привязка"
        case .issued:       return "Карта выпущена"
        case .address:      return "Адрес доставки"
        case .method:       return "Способ доставки"
        case .confirm:      return "Подтверждение"
        case .tracking:     return "Доставка"
        case .burner:       return "Одноразовая карта"
        case .burnerIssued: return "Готово"
        }
    }

    private var stepSubtitle: String? {
        switch step {
        case .design:   return "Виртуальная карта выпускается сразу"
        case .confirm:  return "Проверьте детали заказа"
        default:        return nil
        }
    }

    // MARK: Actions

    private func consumePreset() {
        guard let preset = store.orderPreset else { return }
        store.orderPreset = nil
        draft.product = preset
        if preset == .disposable {
            draft.accountId = store.accounts.first?.id
            step = .burner
        }
    }

    private func advanceFromProduct() {
        if draft.product == .disposable {
            draft.accountId = store.accounts.first?.id
            withAnimation(Motion.smooth) { step = .burner }
            return
        }
        let options = CardDesign.options(for: draft.product, tier: effectiveTier)
        draft.designId = options.first?.id ?? CardDesign.base.id
        if draft.product.bindsToCrypto {
            draft.asset = store.wallets.first?.asset
        } else {
            draft.accountId = store.accounts.first(where: { $0.type == .current })?.id ?? store.accounts.first?.id
        }
        withAnimation(Motion.smooth) { step = .design }
    }

    private func issueVirtual() {
        guard issuedCardId == nil else { return }   // guard against a double-tap re-issuing
        let card = store.issueVirtual(product: draft.product, designId: draft.designId,
                                      accountId: draft.accountId, asset: draft.asset)
        issuedCardId = card.id
        revealed = false
        withAnimation(Motion.smooth) { step = .issued }
    }

    private func confirmPlastic() {
        guard orderId == nil else { return }        // guard against a double-tap duplicating the order
        let account = draft.accountId ?? issuedCard?.accountId ?? store.accounts.first?.id ?? "acc"
        let order = store.startPhysical(virtualCardId: issuedCardId, designId: draft.designId,
                                        accountId: account, asset: draft.asset,
                                        address: draft.address, method: draft.method)
        orderId = order.id
        withAnimation(Motion.smooth) { step = .tracking }
    }

    private func createBurner() {
        guard issuedCardId == nil else { return }   // guard against a double-tap re-generating
        let account = draft.accountId ?? store.accounts.first?.id ?? "acc"
        let card = store.createBurner(
            mode: draft.burnerMode,
            merchant: draft.burnerMode == .merchantLock ? draft.burnerMerchant : nil,
            limit: draft.burnerLimit, accountId: account)
        issuedCardId = card.id
        revealed = false
        withAnimation(Motion.smooth) { step = .burnerIssued }
    }
}
