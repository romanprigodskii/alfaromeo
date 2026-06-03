import SwiftUI

/// Open-a-ruble-deposit wizard (§10.6): сумма → срок → опции (капитализация/пополнение) →
/// подтверждение биометрией → статус. One pushed screen with internal step state (the `CardOrderView`
/// pattern); no nested NavigationStack.
struct OpenDepositView: View {
    let productId: String

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = SavingsStore.shared
    @State private var draft: DepositDraft
    @State private var step: Step = .amount
    @State private var outcome: SavingsOutcome = .processing
    @State private var authorizing = false

    private let product: DepositProduct
    private let bio = BiometricAuthenticator.available()

    private enum Step: Int, Hashable { case amount, term, options, confirm, status }

    init(productId: String) {
        self.productId = productId
        let resolved = SavingsCatalog.depositProduct(id: productId) ?? SavingsCatalog.depositProducts[0]
        self.product = resolved
        _draft = State(initialValue: DepositDraft(product: resolved))
    }

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var tier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var apy: Double { SavingsRates.depositApy(base: product.baseApy, tier: tier) }

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
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
    }

    // MARK: Steps

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .amount:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Сумма вклада").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard {
                    SavingsAmountField(amount: $draft.amount, symbol: "₽", presets: amountPresets)
                }
                hint("Минимум \(SavingsFormat.rub(product.minAmount)) · ставка \(SavingsFormat.percent(apy)) годовых")
                HStack(spacing: Spacing.xs) {
                    Image(systemName: SavingsRisk.insuredASV.systemImage).foregroundStyle(theme.success)
                    Text(SavingsRisk.insuredASV.headline).font(BrandFont.caption).foregroundStyle(theme.success)
                }
            }
        case .term:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Срок").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                HStack(spacing: Spacing.sm) {
                    ForEach(product.termsMonths, id: \.self) { months in
                        selectChip(label: "\(months) мес", selected: draft.termMonths == months) {
                            withAnimation(Motion.snappy) { draft.termMonths = months }
                        }
                    }
                }
                SurfaceCard {
                    summaryRow("Доход за срок", "≈ \(SavingsFormat.rub(draft.projectedInterest(apy: apy)))", tint: theme.success)
                }
            }
        case .options:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Опции").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard {
                    VStack(spacing: Spacing.sm) {
                        if product.allowsCapitalization {
                            Toggle(isOn: $draft.capitalize) {
                                optionLabel("Капитализация процентов", "Проценты прибавляются к телу вклада")
                            }.tint(theme.accent)
                        }
                        if product.allowsTopUp {
                            Toggle(isOn: $draft.topUp) {
                                optionLabel("Пополнение", "Доносить средства в течение срока")
                            }.tint(theme.accent)
                        }
                        if !product.allowsCapitalization && !product.allowsTopUp {
                            optionLabel("Без дополнительных опций", "Фиксированная ставка на весь срок")
                        }
                    }
                }
                hint(product.allowsWithdrawal ? "Снятие доступно без потери процентов." : "Досрочное снятие — по сниженной ставке.")
            }
        case .confirm:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Подтверждение").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard {
                    VStack(spacing: Spacing.sm) {
                        summaryRow("Сумма", SavingsFormat.rub(draft.amount))
                        summaryRow("Ставка", SavingsFormat.percent(apy) + " годовых", tint: theme.success)
                        summaryRow("Срок", "\(draft.termMonths) мес")
                        if product.allowsCapitalization { summaryRow("Капитализация", draft.capitalize ? "да" : "нет") }
                        if product.allowsTopUp { summaryRow("Пополнение", draft.topUp ? "да" : "нет") }
                        Divider().overlay(theme.border)
                        summaryRow("Доход за срок", "≈ \(SavingsFormat.rub(draft.projectedInterest(apy: apy)))", tint: theme.success)
                    }
                }
                HStack(spacing: Spacing.xs) {
                    Image(systemName: SavingsRisk.insuredASV.systemImage).foregroundStyle(theme.success)
                    Text(SavingsRisk.insuredASV.headline).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }
        case .status:
            EmptyView()
        }
    }

    private var statusStep: some View {
        SavingsStatusView(
            outcome: outcome,
            successTitle: "Вклад открыт",
            amountRub: draft.amount,
            caption: "\(SavingsFormat.percent(apy)) годовых · \(draft.termMonths) мес",
            onDone: { router.pop() },
            onRetry: { withAnimation(Motion.smooth) { step = .confirm; outcome = .processing } }
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
        step == .confirm ? "Открыть вклад · \(bio.label)" : "Далее"
    }
    private var footerIcon: String { step == .confirm ? bio.systemImage : "arrow.right" }

    private var canAdvance: Bool {
        switch step {
        case .amount: return draft.meetsMinimum
        default:      return true
        }
    }

    private func advance() {
        switch step {
        case .amount:  withAnimation(Motion.smooth) { step = .term }
        case .term:    withAnimation(Motion.smooth) { step = .options }
        case .options: withAnimation(Motion.smooth) { step = .confirm }
        case .confirm: Task { await authorize() }
        case .status:  break
        }
    }

    private func goBack() {
        let previous = Step(rawValue: max(step.rawValue - 1, 0)) ?? .amount
        withAnimation(Motion.smooth) { step = previous }
    }

    private func authorize() async {
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(reason: "Открытие вклада на \(SavingsFormat.rub(draft.amount))")
        authorizing = false
        guard ok else {
            outcome = .declined(.canceled)
            withAnimation(Motion.smooth) { step = .status }
            return
        }
        outcome = .processing
        withAnimation(Motion.smooth) { step = .status }
        try? await Task.sleep(for: .seconds(1.4))
        store.openDeposit(profileId: profileId, product: product,
                          amount: draft.amount, termMonths: draft.termMonths, apy: apy)
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

    private var amountPresets: [AmountPreset] {
        let base = max(product.minAmount, 50_000)
        return [base, base * 2, base * 5].map { AmountPreset(label: SavingsFormat.rub($0), value: $0) }
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

    private func optionLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
            Text(subtitle).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        OpenDepositView(productId: "dep_term")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
    .environment(Router())
}
