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
                        .padding(Spacing.md)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(product.kind.amountNoun).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                CreditAmountField(amount: $draft.amount, presets: amountPresets,
                                  range: product.minAmount...requestable)
            }
            amountStatusBanner

            Text("Срок").font(BrandFont.headline).foregroundStyle(theme.textPrimary).padding(.top, Spacing.xs)
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
                }
                .onAppear { proxy.scrollTo(draft.termMonths, anchor: .trailing) }
            }

            paymentPreview
        }
    }

    private var paymentPreview: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ежемесячный платёж").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Text("\(CreditFormat.rub(monthlyPayment))")
                        .font(BrandFont.mono(24, weight: .semibold)).foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ставка").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Text(product.kind.isInterestFree ? "0%" : CreditFormat.rate(rate))
                        .font(BrandFont.mono(18, weight: .medium)).foregroundStyle(theme.textPrimary)
                }
            }
            .animation(Motion.snappy, value: monthlyPayment)
        }
    }

    /// Honest status for the chosen amount: within the instant pre-approval, or above it (needs
    /// verification). Either way the user is free to pick any amount up to `requestable`.
    @ViewBuilder private var amountStatusBanner: some View {
        if abovePreApproved {
            SurfaceCard {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "info.circle").foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Выше преодобренного \(CreditFormat.rub(preApproved))")
                            .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Text("Сумму сверх преодобренной банк подтвердит по доходу — итоговое решение по заявке. Можно подтвердить доход и поднять преодобренный лимит.")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Поднять лимит — симулятор") { router.push(CreditRoute.prequal) }
                            .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                            .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        } else {
            SurfaceCard {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle").foregroundStyle(theme.success)
                    Text("В пределах преодобренного \(CreditFormat.rub(preApproved)) — решение мгновенное.")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Расчёт платежей").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            ScheduleTable(
                monthlyPayment: monthlyPayment,
                overpay: LoanMath.overpay(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                total: LoanMath.totalPaid(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                rows: LoanMath.schedule(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths),
                interestFree: product.kind.isInterestFree)
            hint("Аннуитет: платёж фиксирован, доля процентов уменьшается к концу срока. Досрочное погашение — без штрафа.")
        }
    }

    private var consentsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Согласия").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    CreditConsentRow(title: "Запрос кредитной истории в БКИ",
                               subtitle: "Разрешаю запросить отчёт в бюро кредитных историй.",
                               isOn: $draft.consentBureau)
                    Divider().overlay(theme.border)
                    CreditConsentRow(title: "Обработка персональных данных",
                               subtitle: "Согласие на обработку данных для оценки заявки (152-ФЗ).",
                               isOn: $draft.consentData)
                    Divider().overlay(theme.border)
                    CreditConsentRow(title: "Индивидуальные условия договора",
                               subtitle: "Ознакомлен и принимаю условия кредитного договора.",
                               isOn: $draft.consentTerms)
                }
            }
            if !draft.allConsentsGiven {
                hint("Все три согласия обязательны для оформления.", tint: theme.warning)
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Проверьте условия").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                VStack(spacing: Spacing.sm) {
                    summaryRow("Продукт", product.name)
                    summaryRow(product.kind.amountNoun, CreditFormat.rub(clampedAmount), tint: theme.accent)
                    summaryRow("Срок", CreditFormat.term(draft.termMonths))
                    summaryRow("Ставка", product.kind.isInterestFree ? "0%" : CreditFormat.rate(rate))
                    Divider().overlay(theme.border)
                    summaryRow("Платёж в месяц", CreditFormat.rub(monthlyPayment))
                    summaryRow(product.kind.isInterestFree ? "Без переплаты" : "Переплата",
                               product.kind.isInterestFree ? "0 ₽"
                               : CreditFormat.rub(LoanMath.overpay(principal: clampedAmount, annualRatePercent: rate, months: draft.termMonths)))
                }
            }
            HStack(spacing: Spacing.xs) {
                Image(systemName: bio.systemImage).foregroundStyle(theme.accent)
                Text("Подтверждение операции \(bio.label) (§10.1)").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
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
                .opacity(canAdvance ? 1 : 0.5)
            if step != .params {
                SecondaryButton(title: "Назад") { goBack() }
            }
        }
        .padding(Spacing.md)
        .background(theme.background)
    }

    private var footerTitle: String {
        step == .confirm ? "Подтвердить · \(bio.label)" : "Далее"
    }
    private var footerIcon: String { step == .confirm ? bio.systemImage : "arrow.right" }

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
                Capsule().fill(i <= step.rawValue ? theme.accent : theme.border).frame(height: 4)
            }
        }
    }

    /// Quick-pick chips spanning the requestable range: the pre-approved sum, round milestones, and the
    /// max — deduped, clamped, rounded to a clean 10k.
    private var amountPresets: [CreditAmountPreset] {
        guard requestable > 0 else { return [] }
        let candidates: [(Double, String)] = [
            (preApproved, "Преодобрено"),
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
                .font(BrandFont.callout)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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

    private func hint(_ text: String, tint: Color? = nil) -> some View {
        Text(text).font(BrandFont.caption).foregroundStyle(tint ?? theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
