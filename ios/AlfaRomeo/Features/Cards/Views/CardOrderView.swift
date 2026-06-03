import SwiftUI

/// Заказ карты (§6.2) — a self-contained, multi-step wizard pushed as the single `.order` route:
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
                    .padding(Spacing.lg)
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
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.accent).frame(width: 32, height: 32)
                            .background(theme.elevated, in: Circle())
                    }.buttonStyle(.plain)
                }
                Text(stepTitle).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Spacer()
            }
            if let sub = stepSubtitle {
                Text(sub).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !canAddPrimaryNow {
                UpsellCard(
                    title: "Лимит карт на тарифе \(effectiveTier.shortLabel)",
                    message: "Доступно карт: \(ent.maxCardsLabel). Одноразовую можно выпустить всегда — она не занимает лимит. Для обычной карты повысьте тариф.",
                    recommendedTier: recommendedTier)
            }
            ForEach(CardProduct.allCases) { product in
                selectableCard(
                    icon: product.icon, title: product.title, subtitle: product.subtitle,
                    selected: draft.product == product,
                    locked: !canAddPrimaryNow && product != .disposable
                ) { draft.product = product }
            }
            Text("Одноразовые карты — эфемерные токены безопасности: не занимают лимит тарифа.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            PrimaryButton(title: "Далее", icon: "arrow.right") { advanceFromProduct() }
                .disabled(draft.product != .disposable && !canAddPrimaryNow)
        }
    }

    // 2 ── Design + binding
    private var designStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sectionLabel("Дизайн / тир")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(CardDesign.options(for: draft.product, tier: effectiveTier)) { design in
                        Button { withAnimation(Motion.snappy) { draft.designId = design.id } } label: {
                            VStack(spacing: Spacing.xs) {
                                CardFaceView(card: previewCard(design.id)).frame(width: 210)
                                Text(design.name).font(BrandFont.caption.weight(.semibold))
                                    .foregroundStyle(theme.textPrimary)
                            }
                            .padding(Spacing.sm)
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .stroke(draft.designId == design.id ? theme.accent : .clear, lineWidth: 2))
                        }.buttonStyle(.plain)
                    }
                }
            }

            if draft.product.bindsToCrypto {
                sectionLabel("Списывать с актива")
                bindingList(store.wallets.map { ($0.asset, "\($0.asset) · \($0.chain)", "\($0.balance) \($0.asset)") },
                            selectedId: draft.asset) { draft.asset = $0 }
            } else {
                sectionLabel("Привязать к счёту")
                bindingList(store.accounts.map { ($0.id, accountTitle($0), "\(Int($0.balance)) \($0.currency)") },
                            selectedId: draft.accountId) { draft.accountId = $0 }
            }

            PrimaryButton(title: "Выпустить виртуальную мгновенно", icon: "bolt.fill") { issueVirtual() }
        }
    }

    // 3 ── Virtual issued (instant)
    @ViewBuilder
    private var issuedStep: some View {
        if let card = issuedCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                StatusPill(status: .success, text: "Выпущена мгновенно · доступна для оплат")
                CardFaceView(card: card).frame(maxWidth: 300).frame(maxWidth: .infinity)
                CardRequisitesCard(card: card, revealed: $revealed)
                walletButton(card)

                if draft.product.allowsPlastic {
                    if canAddPrimaryNow {
                        PrimaryButton(title: "Заказать пластик", icon: "shippingbox") {
                            withAnimation(Motion.smooth) { step = .address }
                        }
                    } else {
                        UpsellCard(
                            title: "Пластик — на тарифе выше",
                            message: "На \(effectiveTier.displayName) доступно карт: \(ent.maxCardsLabel). Виртуальная уже у вас — для пластика повысьте тариф.",
                            recommendedTier: recommendedTier)
                    }
                }
                SecondaryButton(title: "Готово") { router.pop() }
            }
        }
    }

    // 4a ── Address
    private var addressStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Куда доставить")
            TextField("Город, улица, дом, квартира", text: $draft.address, axis: .vertical)
                .lineLimit(2...4)
                .font(BrandFont.bodyM)
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
            Button {
                withAnimation(Motion.snappy) { draft.address = "Москва, Пресненская наб., 8, кв. 142" }
            } label: {
                Label("Определить по геолокации (демо)", systemImage: "location.fill")
                    .font(BrandFont.callout).foregroundStyle(theme.accent)
            }.buttonStyle(.plain)
            Spacer(minLength: Spacing.lg)
            PrimaryButton(title: "Далее", icon: "arrow.right") { withAnimation(Motion.smooth) { step = .method } }
                .disabled(draft.address.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // 4b ── Method (cost by tier)
    private var methodStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Способ доставки")
            ForEach(DeliveryMethod.allCases) { method in
                selectableCard(
                    icon: method.icon, title: method.label,
                    subtitle: method.detail, trailing: method.priceLabel(for: effectiveTier),
                    selected: draft.method == method
                ) { draft.method = method }
            }
            Text("Стоимость зависит от тарифа: Pro — со скидкой, Infinite — бесплатно.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            PrimaryButton(title: "Далее", icon: "arrow.right") { withAnimation(Motion.smooth) { step = .confirm } }
        }
    }

    // 4c ── Confirm
    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    summaryRow("Карта", CardDesign.design(for: draft.designId).name)
                    Divider().overlay(theme.border)
                    summaryRow("Доставка", "\(draft.method.label) · \(draft.method.detail)")
                    Divider().overlay(theme.border)
                    summaryRow("Адрес", draft.address)
                    Divider().overlay(theme.border)
                    summaryRow("Стоимость", draft.method.priceLabel(for: effectiveTier), emphasised: true)
                }
            }
            PrimaryButton(title: "Подтвердить и заказать", icon: "checkmark") { confirmPlastic() }
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sectionLabel("Режим")
            ForEach(BurnerMode.allCases) { mode in
                selectableCard(icon: mode.icon, title: mode.title, subtitle: mode.detail,
                               selected: draft.burnerMode == mode) { draft.burnerMode = mode }
            }
            if draft.burnerMode == .merchantLock {
                sectionLabel("Мерчант")
                TextField("Например, Steam", text: $draft.burnerMerchant)
                    .font(BrandFont.bodyM).padding(Spacing.md)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
            }
            sectionLabel("Лимит")
            HStack {
                Slider(value: $draft.burnerLimit, in: 1_000...100_000, step: 1_000).tint(theme.accent)
                AmountText(amount: draft.burnerLimit, size: 17).frame(width: 110, alignment: .trailing)
            }
            sectionLabel("Счёт списания")
            bindingList(store.accounts.map { ($0.id, accountTitle($0), "\(Int($0.balance)) \($0.currency)") },
                        selectedId: draft.accountId ?? store.accounts.first?.id) { draft.accountId = $0 }
            PrimaryButton(title: "Сгенерировать одноразовую", icon: "bolt.fill") { createBurner() }
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
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label(burner.statusLabel, systemImage: "flame")
                                .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.warning)
                            Text("Лимит \(Int(burner.limit)) ₽. \(burner.mode.detail).")
                                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        }
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
                    .background(BrandColors.black, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }.buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func selectableCard(icon: String, title: String, subtitle: String,
                                trailing: String? = nil, selected: Bool, locked: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button(action: { if !locked { withAnimation(Motion.snappy, action) } }) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? theme.onAccent : theme.accent)
                    .frame(width: 40, height: 40)
                    .background(selected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.accent.opacity(0.14)),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM.weight(.semibold)).foregroundStyle(theme.textPrimary)
                    Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.sm)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(theme.textSecondary)
                } else if let trailing {
                    Text(trailing).font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
                }
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
            .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    private func bindingList(_ items: [(String, String, String)], selectedId: String?,
                             onPick: @escaping (String) -> Void) -> some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Button { withAnimation(Motion.snappy) { onPick(item.0) } } label: {
                        ListRow(icon: selectedId == item.0 ? "checkmark.circle.fill" : "circle",
                                iconTint: selectedId == item.0 ? theme.accent : theme.textSecondary,
                                title: item.1, subtitle: item.2)
                    }.buttonStyle(.plain)
                    if i < items.count - 1 { Divider().overlay(theme.border) }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
    }

    private func summaryRow(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(emphasised ? BrandFont.headline : BrandFont.callout)
                .foregroundStyle(emphasised ? theme.accent : theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        case .product:  return "Дебет / кредит / крипто / одноразовая (§6.2)"
        case .design:   return "Виртуальная выпустится мгновенно"
        case .issued:   return "Доступна для оплат прямо сейчас"
        case .confirm:  return "Проверьте детали заказа"
        case .burner:   return "Мгновенная генерация, авто-сжигание"
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
