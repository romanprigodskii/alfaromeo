import SwiftUI

/// Credit-application wizard (§10.5 оформление): сумма/срок → расчёт платежа/графика → согласия →
/// биометрия → статус. The amount is clamped to the pre-qualified limit, so requesting more than the
/// approved sum surfaces honest «частичное одобрение» rather than a silent cap.
struct CreditApplyView: View {
    let productId: String

    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = CreditStore.shared
    @State private var draft: CreditDraft
    @State private var step: Step
    @State private var outcome: CreditOutcome = .processing
    @State private var authorizing = false

    private let product: CreditProduct
    private let bio = BiometricAuthenticator.available()

    enum Step: Int, Hashable { case params, schedule, consents, confirm, status }

    init(productId: String, startAt: Step = .params) {
        self.productId = productId
        let resolved = CreditCatalog.product(id: productId) ?? CreditCatalog.primary
        self.product = resolved
        // Suggested amount = the base approved limit (pure, from demo inputs — no @MainActor access).
        let limit = PrequalEngine.approvedLimit(for: resolved, inputs: CreditStore.demoInputs)
        var d = CreditDraft(product: resolved, suggestedAmount: limit > 0 ? limit : resolved.minAmount)
        // Pre-fill consents when a downstream step is the entry point (harness/preview convenience).
        if startAt == .schedule || startAt == .confirm {
            d.consentBureau = true; d.consentData = true; d.consentTerms = true
        }
        _draft = State(initialValue: d)
        _step = State(initialValue: startAt)
    }

    private var profileId: String { session.activeProfile?.id ?? "" }
    /// Pre-approved (instant) amount — granted with no extra verification (the simulator's hypothetical
    /// levers don't apply here).
    private var preApproved: Double { max(store.approvedLimit(for: product), PrequalEngine.approvedLimit(for: product, inputs: CreditStore.demoInputs)) }
    /// Self-request ceiling — the user may pick ANY amount up to here (§10.5, «до 2 млн»); the part above
    /// `preApproved` is granted subject to income verification.
    private var requestable: Double { CreditStore.requestableLimit(for: product, preApproved: preApproved) }
    private var rate: Double { PrequalEngine.rate(for: product, score: CreditStore.demoInputs.creditScore) }
    private var clampedAmount: Double { min(max(draft.amount, 0), requestable) }
    private var monthlyPayment: Double {
        LoanMath.monthlyPayment(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths)
    }
    /// Chosen amount exceeds the instantly pre-approved sum → needs verification (honest labelling).
    private var abovePreApproved: Bool { clampedAmount > preApproved + 0.5 }

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
                        .padding(.horizontal, Spacing.screen)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.lg)
                    }
                    footer
                }
                .background(theme.background.ignoresSafeArea())
            }
        }
        .navigationTitle(titleForStep)
        .navigationBarTitleDisplayMode(.inline)
        .creditExitToolbar()
        .task(id: profileId) { store.load(profileId: profileId) }
    }

    private var titleForStep: String {
        switch step {
        case .params:   return product.name
        case .schedule: return "График платежей"
        case .consents: return "Согласия"
        case .confirm:  return "Подтверждение"
        case .status:   return ""
        }
    }

    // MARK: Steps

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .params:   paramsStep
        case .schedule: scheduleStep
        case .consents: consentsStep
        case .confirm:  confirmStep
        case .status:   EmptyView()
        }
    }

    private var paramsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                SectionHeader(product.kind.amountNoun)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        CreditAmountField(amount: $draft.amount, presets: amountPresets,
                                          range: product.minAmount...requestable)
                        Hairline()
                        amountStatus
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                SectionHeader("Срок")
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(product.termOptionsMonths, id: \.self) { months in
                                selectChip(label: CreditFormat.term(months), selected: draft.termMonths == months) {
                                    withAnimation(Motion.snappy) { draft.termMonths = months }
                                }
                                .id(months)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, Spacing.screen)
                    }
                    .padding(.horizontal, -Spacing.screen)
                    .onAppear { proxy.scrollTo(draft.termMonths, anchor: .center) }
                }
            }

            paymentPreview
        }
    }

    private var rateText: String {
        product.kind.isInterestFree ? CreditFormat.rate(0) : CreditFormat.rate(rate)
    }

    private var paymentPreview: some View {
        SurfaceCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Платёж в месяц").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Text(CreditFormat.rub(monthlyPayment))
                        .font(BrandFont.mono(28, weight: .semibold)).foregroundStyle(theme.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ставка").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Text(rateText)
                        .font(BrandFont.mono(17)).foregroundStyle(theme.textPrimary)
                }
            }
            .animation(Motion.snappy, value: monthlyPayment)
        }
    }

    /// Honest status for the chosen amount: within the instant pre-approval, or above it (needs
    /// verification). Either way the user is free to pick any amount up to `requestable`.
    @ViewBuilder private var amountStatus: some View {
        if abovePreApproved {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Выше предодобренных \(CreditFormat.rub(preApproved))")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Сумму сверх предодобренной банк подтвердит по доходу, итоговое решение по заявке. Подтвердите доход, чтобы поднять предодобренный лимит.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Поднять лимит") { router.push(CreditRoute.prequal) }
                    .font(BrandFont.body(15, weight: .medium)).foregroundStyle(theme.accent)
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, Spacing.xxs)
            }
        } else {
            Text("В пределах предодобренных \(CreditFormat.rub(preApproved)), решение мгновенное.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ScheduleTable(
                monthlyPayment: monthlyPayment,
                overpay: LoanMath.overpay(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                total: LoanMath.totalPaid(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                rows: LoanMath.schedule(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                interestFree: product.kind.isInterestFree)
            hint("Платёж фиксирован, доля процентов уменьшается к концу срока. Досрочное погашение без штрафа.")
        }
    }

    private var consentsStep: some View {
        GroupedSection(footer: "Все три согласия обязательны для оформления.") {
            CreditConsentRow(title: "Запрос кредитной истории в БКИ",
                             subtitle: "Разрешаю запросить отчёт в бюро кредитных историй.",
                             isOn: $draft.consentBureau)
            CreditConsentRow(title: "Обработка персональных данных",
                             subtitle: "Согласие на обработку данных для оценки заявки (152-ФЗ).",
                             isOn: $draft.consentData)
            CreditConsentRow(title: "Индивидуальные условия договора",
                             subtitle: "Ознакомлен и принимаю условия кредитного договора.",
                             isOn: $draft.consentTerms)
        }
    }

    private var confirmStep: some View {
        GroupedSection("Условия", footer: "Заявка подтверждается через \(bio.label).") {
            ListRow(title: "Продукт", value: product.name)
            ListRow(title: product.kind.amountNoun, value: CreditFormat.rub(clampedAmount))
            ListRow(title: "Срок", value: CreditFormat.term(draft.termMonths))
            ListRow(title: "Ставка", value: rateText)
            ListRow(title: "Платёж в месяц", value: CreditFormat.rub(monthlyPayment))
            ListRow(title: "Переплата",
                    value: product.kind.isInterestFree ? CreditFormat.rub(0)
                        : CreditFormat.rub(LoanMath.overpay(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths)))
        }
    }

    private var statusStep: some View {
        CreditStatusView(
            outcome: outcome,
            productKind: product.kind,
            amount: clampedAmount,
            caption: "Платёж \(CreditFormat.rub(monthlyPayment))/мес · \(CreditFormat.term(draft.termMonths))",
            onDone: { router.pop() },
            onRetry: { retry() })
    }

    // MARK: Footer / navigation

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: footerTitle, icon: footerIcon, isLoading: authorizing) { advance() }
                .disabled(!canAdvance || authorizing)
            if step != .params {
                SecondaryButton(title: "Назад") { goBack() }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.sm)
        .background(theme.background)
    }

    private var footerTitle: String {
        step == .confirm ? "Подтвердить" : "Далее"
    }
    private var footerIcon: String? { step == .confirm ? bio.systemImage : nil }

    private var canAdvance: Bool {
        switch step {
        case .params:   return requestable > 0 && clampedAmount >= product.minAmount
        case .schedule: return true
        case .consents: return draft.allConsentsGiven
        case .confirm:  return draft.allConsentsGiven
        case .status:   return true
        }
    }

    private func advance() {
        switch step {
        case .params:   draft.amount = clampedAmount; withAnimation(Motion.smooth) { step = .schedule }
        case .schedule: withAnimation(Motion.smooth) { step = .consents }
        case .consents: withAnimation(Motion.smooth) { step = .confirm }
        case .confirm:  Task { await authorize() }
        case .status:   break
        }
    }

    private func goBack() {
        let previous = Step(rawValue: max(step.rawValue - 1, 0)) ?? .params
        withAnimation(Motion.smooth) { step = previous }
    }

    private func retry() {
        // The only decline the flow can actually produce is .canceled (biometrics) → back to .confirm.
        // .noConsent is a defence-in-depth guard (canAdvance already requires consents) → .consents.
        let target: Step = { if case .declined(.noConsent) = outcome { return .consents }; return .confirm }()
        withAnimation(Motion.smooth) { step = target; outcome = .processing }
    }

    private func authorize() async {
        guard draft.allConsentsGiven else {
            outcome = .declined(.noConsent)
            withAnimation(Motion.smooth) { step = .status }
            return
        }
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(
            reason: "Оформление кредита на \(CreditFormat.rub(clampedAmount))")
        authorizing = false
        guard ok else {
            outcome = .declined(.canceled)
            withAnimation(Motion.smooth) { step = .status }
            return
        }
        outcome = .processing
        withAnimation(Motion.smooth) { step = .status }
        try? await Task.sleep(for: .seconds(1.4))
        store.open(product: product, amount: clampedAmount, rate: rate, termMonths: draft.termMonths)
        outcome = .success
    }

    // MARK: Small builders

    private var progressDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= step.rawValue ? theme.accent : theme.fill).frame(height: 4)
            }
        }
    }

    /// Quick-pick chips spanning the requestable range: the pre-approved sum, round milestones, and the
    /// max — deduped, clamped, rounded to a clean 10k.
    private var amountPresets: [CreditAmountPreset] {
        guard requestable > 0 else { return [] }
        let candidates: [(Double, String)] = [
            (preApproved, "Предодобрено"),
            (1_000_000, "1 млн"),
            (1_500_000, "1,5 млн"),
            (requestable, "Макс"),
        ]
        var seen = Set<Int>()
        return candidates.compactMap { value, label in
            let v = (min(max(value, product.minAmount), requestable) / 10_000).rounded() * 10_000
            guard v >= product.minAmount, seen.insert(Int(v)).inserted else { return nil }
            return CreditAmountPreset(label: label, value: v)
        }
    }

    private func selectChip(label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BrandFont.subheadline.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                .padding(.horizontal, Spacing.md).frame(height: 36)
                .background(selected ? theme.accent : theme.surface,
                            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func hint(_ text: String, tint: Color? = nil) -> some View {
        Text(text).font(BrandFont.footnote).foregroundStyle(tint ?? theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        CreditApplyView(productId: "cr_cash")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.theme, .default)
    .environment(Router())
}
