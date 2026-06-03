import SwiftUI

/// Crypto-staking wizard (§10.6): актив → сумма (₽-оценка по live-цене) → срок lock → раскрытие
/// риска (обязательный чекбокс) → подтверждение биометрией → статус. Soft compliance: a неквал
/// investor is gated at the confirm step (before biometrics) against the cumulative 300 000 ₽/год
/// limit (§2.4).
struct StakeFlowView: View {
    let productId: String

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = SavingsStore.shared
    @State private var draft: StakeDraft
    @State private var step: Step = .amount
    @State private var outcome: SavingsOutcome = .processing
    @State private var authorizing = false

    private let product: StakeProduct
    private let bio = BiometricAuthenticator.available()

    private enum Step: Int, Hashable { case amount, lock, risk, confirm, status }

    init(productId: String) {
        self.productId = productId
        let resolved = SavingsCatalog.stakeProduct(id: productId) ?? SavingsCatalog.stakeProducts[0]
        self.product = resolved
        _draft = State(initialValue: StakeDraft(product: resolved))
    }

    /// Entry from the Crypto hub by asset symbol (§9.6 «стейкинг — вход из детейла»). Assets the
    /// licensed platform doesn't stake (e.g. SOL/TON) fall back to the first product, matching the
    /// id-based initializer's behaviour above.
    init(symbol: String) {
        self.init(productId: SavingsCatalog.stakeProduct(asset: symbol)?.id ?? SavingsCatalog.stakeProducts[0].id)
    }

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var tier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var apy: Double { SavingsRates.stakeApy(base: product.baseApy, tier: tier) }
    private var unitPrice: Double { store.price(for: product.asset) }
    private var estimateRub: Double { store.rubValue(units: draft.amountUnits, asset: product.asset) }

    private var unqualified: Bool { session.currentUser?.investorStatus == .unqualified }
    /// Would this stake push the in-app YTD total past the неквал cap (300 000 ₽/год, §2.4)?
    private var exceedsYearLimit: Bool {
        unqualified && (store.stakedRubThisYear(profileId: profileId) + estimateRub) > 300_000
    }

    var body: some View {
        Group {
            if step == .status {
                statusStep
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            progressDots
                            stepBody
                        }
                        .padding(Spacing.md)
                    }
                    footer
                }
                .background(theme.background.ignoresSafeArea())
            }
        }
        .navigationTitle("Стейкинг \(product.asset)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await store.streamPrices() }
    }

    // MARK: Steps

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .amount:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Сколько застейкать").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard {
                    SavingsAmountField(amount: $draft.amountUnits, symbol: product.asset,
                                       presets: unitPresets, allowsDecimals: true)
                }
                // Live ₽ estimate — updates with each price tick (§10.6 «оценка стейка в ₽ по live-цене»).
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("≈ \(SavingsFormat.rub(estimateRub))")
                            .font(BrandFont.mono(24, weight: .semibold))
                            .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                            .contentTransition(.numericText())
                        Text("по курсу \(SavingsFormat.rub(unitPrice)) / \(product.asset) · live")
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(Motion.snappy, value: estimateRub)
                }
                if let balance = store.wallet(asset: product.asset)?.balance {
                    hint("Доступно: \(SavingsFormat.units(balance, asset: product.asset))")
                }
                hint("Минимум \(SavingsFormat.units(product.minUnits, asset: product.asset)) · APY \(SavingsFormat.percent(apy))")
            }
        case .lock:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Срок lock").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                HStack(spacing: Spacing.sm) {
                    ForEach(product.lockOptionsDays, id: \.self) { days in
                        selectChip(label: days == 0 ? "Гибкий" : "\(days) дн", selected: draft.lockDays == days) {
                            withAnimation(Motion.snappy) { draft.lockDays = days }
                        }
                    }
                }
                hint(draft.lockDays == 0
                     ? "Гибкий стейкинг: вывод в любой момент, APY ниже."
                     : "Чем дольше lock — тем выше доход. Досрочный вывод недоступен до конца срока.")
            }
        case .risk:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Раскрытие риска").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                StakeRiskDisclosure(accepted: $draft.riskAccepted)
            }
        case .confirm:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Подтверждение").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard {
                    VStack(spacing: Spacing.sm) {
                        summaryRow("Актив", product.name)
                        summaryRow("Сумма", SavingsFormat.units(draft.amountUnits, asset: product.asset))
                        summaryRow("≈ в рублях", SavingsFormat.rub(estimateRub), tint: theme.accentCrypto.first ?? theme.accent)
                        summaryRow("APY", SavingsFormat.percent(apy))
                        summaryRow("Lock", draft.lockDays == 0 ? "гибкий" : "\(draft.lockDays) дн")
                    }
                }
                HStack(spacing: Spacing.xs) {
                    Image(systemName: SavingsRisk.marketRisk.systemImage).foregroundStyle(theme.warning)
                    Text(SavingsRisk.marketRisk.headline).font(BrandFont.caption).foregroundStyle(theme.warning)
                }
                if exceedsYearLimit { limitWarning }
            }
        case .status:
            EmptyView()
        }
    }

    private var limitWarning: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent").foregroundStyle(theme.danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Превышен годовой лимит").font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                    Text("Для неквалифицированного инвестора — 300 000 ₽ в год (§2.4). Уменьшите сумму или повысьте статус инвестора.")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statusStep: some View {
        SavingsStatusView(
            outcome: outcome,
            successTitle: "Стейкинг активен",
            amountRub: estimateRub,
            caption: "\(SavingsFormat.percent(apy)) APY · \(draft.lockDays == 0 ? "гибкий" : "\(draft.lockDays) дн")",
            onDone: { router.pop() },
            onRetry: { retry() }
        )
    }

    // MARK: Footer / navigation

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: footerTitle, icon: footerIcon, isLoading: authorizing) { advance() }
                .disabled(!canAdvance || authorizing)
                .opacity(canAdvance ? 1 : 0.5)
            if step == .confirm {
                Text("Подтверждение операции биометрией (§10.6)")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            if step != .amount {
                SecondaryButton(title: "Назад") { goBack() }
            }
        }
        .padding(Spacing.md)
        .background(theme.background)
    }

    private var footerTitle: String {
        step == .confirm ? "Подтвердить стейкинг · \(bio.label)" : "Далее"
    }
    private var footerIcon: String { step == .confirm ? bio.systemImage : "arrow.right" }

    private var canAdvance: Bool {
        switch step {
        case .amount:  return draft.meetsMinimum
        case .risk:    return draft.riskAccepted
        case .confirm: return draft.riskAccepted && !exceedsYearLimit
        case .lock, .status: return true
        }
    }

    private func advance() {
        switch step {
        case .amount:  withAnimation(Motion.smooth) { step = .lock }
        case .lock:    withAnimation(Motion.smooth) { step = .risk }
        case .risk:    withAnimation(Motion.smooth) { step = .confirm }
        case .confirm: Task { await authorize() }
        case .status:  break
        }
    }

    private func goBack() {
        let previous = Step(rawValue: max(step.rawValue - 1, 0)) ?? .amount
        withAnimation(Motion.smooth) { step = previous }
    }

    private func retry() {
        let target: Step
        switch outcome {
        case .declined(.riskNotAccepted):   target = .risk
        case .declined(.overLimit):         target = .amount
        case .declined(.insufficientFunds): target = .amount
        default:                            target = .confirm
        }
        withAnimation(Motion.smooth) { step = target; outcome = .processing }
    }

    private func authorize() async {
        // Risk acceptance and the неквал year-limit are already gated by `canAdvance` on .confirm;
        // the risk guard stays as defence-in-depth.
        guard draft.riskAccepted else {
            outcome = .declined(.riskNotAccepted)
            withAnimation(Motion.smooth) { step = .status }
            return
        }
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(
            reason: "Стейкинг \(SavingsFormat.units(draft.amountUnits, asset: product.asset))")
        authorizing = false
        guard ok else {
            outcome = .declined(.canceled)
            withAnimation(Motion.smooth) { step = .status }
            return
        }
        outcome = .processing
        withAnimation(Motion.smooth) { step = .status }
        try? await Task.sleep(for: .seconds(1.4))
        store.openStake(profileId: profileId, product: product,
                        units: draft.amountUnits, lockDays: draft.lockDays, apy: apy)
        outcome = .success
    }

    // MARK: Small builders

    private var progressDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= step.rawValue ? theme.accent : theme.border).frame(height: 4)
            }
        }
    }

    private var unitPresets: [AmountPreset] {
        if let balance = store.wallet(asset: product.asset)?.balance, balance > 0 {
            return [(0.25, "25%"), (0.5, "50%"), (1.0, "Всё")].map { fraction, label in
                AmountPreset(label: label, value: balance * fraction)
            }
        }
        let m = product.minUnits
        return [m, m * 5, m * 20].map { AmountPreset(label: SavingsFormat.units($0, asset: product.asset), value: $0) }
    }

    private func selectChip(label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BrandFont.callout)
                .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                .background(selected ? theme.accent : theme.elevated, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func summaryRow(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(BrandFont.body().weight(.semibold)).foregroundStyle(tint ?? theme.textPrimary)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        StakeFlowView(productId: "stk_eth")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
    .environment(Router())
}
