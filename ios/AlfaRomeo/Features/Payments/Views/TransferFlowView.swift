import SwiftUI

/// The unified transfer / payment wizard (§9.2 / §10.3). One pushed screen that walks the steps
/// получатель → сумма → подтверждение(биометрия) → статус, driven by ``TransferFlowModel``. Mirrors
/// the existing ``RegistrationView`` stepper so the shared draft + biometric + status state lives in
/// one place instead of being drilled across `NavigationPath` value routes.
struct TransferFlowView: View {
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var model: TransferFlowModel
    private let bio = BiometricAuthenticator.available()

    init(kind: TransferKind, biller: Biller? = nil) {
        _model = State(initialValue: TransferFlowModel(kind: kind, biller: biller))
    }

    var body: some View {
        Group {
            switch model.step {
            case .recipient: scroll { recipientStep }
            case .amount:    scroll { amountStep }
            case .confirm:   scroll { confirmStep }
            case .status:    statusStep
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showsInFlowBack || model.step == .status)
        .toolbar {
            if showsInFlowBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation(Motion.smooth) { model.stepBack() } } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .animation(Motion.smooth, value: model.step)
        .task { await model.load(api: api, session: session) }
    }

    private func scroll<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) { content() }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    private var navTitle: String { model.prefilledBiller?.name ?? model.kind.title }

    /// Show an in-flow back chevron (instead of popping to the hub) on non-first, non-status steps.
    private var showsInFlowBack: Bool {
        !model.atFirstStep && model.step != .status
    }

    // MARK: - Step 1 · Recipient

    @ViewBuilder private var recipientStep: some View {
        switch model.kind.recipientStyle {
        case .accounts:      betweenAccountsRecipient
        case .phoneContact:  phoneRecipient
        case .cryptoContact: cryptoRecipient
        case .cardNumber:    cardRecipient
        case .requisites:    requisitesRecipient
        case .abroad:        abroadRecipient
        case .qr:            qrRecipient
        }
    }

    private var betweenAccountsRecipient: some View {
        let candidates = model.accounts.filter(\.isRubLike)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Куда перевести", "Выберите счёт зачисления.")
            if model.accounts.isEmpty {
                ProgressView().tint(theme.accent)
            } else if candidates.count < 2 {
                // No distinct second ₽ account (e.g. a business profile with one РКО счёт) — guard the
                // dead always-declined flow instead of offering it.
                SurfaceCard {
                    Text("Для перевода между своими счетами нужно минимум два счёта в ₽.")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, acc in
                            Button { withAnimation(Motion.smooth) { model.selectDestinationAccount(acc) } } label: {
                                ListRow(icon: acc.type.paymentsIcon, title: acc.displayTitle,
                                        subtitle: acc.displaySubtitle, value: money(acc.balance, acc.symbol),
                                        showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            if index < candidates.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
            }
        }
    }

    private var phoneRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Кому перевести", "По номеру телефона через СБП — мгновенно и без комиссии.")
            HStack(spacing: Spacing.sm) {
                field($model.phone, placeholder: "+7 ___ ___-__-__", keyboard: .phonePad, mono: true)
                Button { withAnimation(Motion.smooth) { model.commitTypedPhone() } } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 52, height: 52)
                        .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.phone.filter(\.isNumber).count < 10)
            }
            Text("Недавние контакты").font(BrandFont.micro).tracking(1).foregroundStyle(theme.textSecondary)
            ContactPickerList(contacts: PaymentsMockData.contacts) { contact in
                withAnimation(Motion.smooth) { model.selectContactSBP(contact) }
            }
        }
    }

    private var cryptoRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Крипто-перевод контакту", "Получатель видит сумму в ₽ — конвертация под капотом (§10.3).")
            ContactPickerList(contacts: PaymentsMockData.contacts, showsWalletHint: true) { contact in
                withAnimation(Motion.smooth) { model.selectContactCrypto(contact) }
            }
        }
    }

    private var cardRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Номер карты", "Перевод на карту в любой банк.")
            field(Binding(
                get: { model.cardNumber },
                set: { model.cardNumber = String($0.filter(\.isNumber).prefix(16)) }
            ), placeholder: "0000 0000 0000 0000", keyboard: .numberPad, mono: true)
            PrimaryButton(title: "Далее", icon: "arrow.right") {
                withAnimation(Motion.smooth) { model.commitCard() }
            }
            .disabled(model.cardNumber.filter(\.isNumber).count < 16)
        }
    }

    private var requisitesRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Реквизиты получателя", "Перевод юр- или физлицу по банковским реквизитам.")
            field($model.receiverName, placeholder: "Получатель (ФИО / организация)")
            field($model.account, placeholder: "Номер счёта", keyboard: .numberPad, mono: true)
            field($model.bik, placeholder: "БИК банка", keyboard: .numberPad, mono: true)
            field($model.inn, placeholder: "ИНН (необязательно)", keyboard: .numberPad, mono: true)
            PrimaryButton(title: "Далее", icon: "arrow.right") {
                withAnimation(Motion.smooth) { model.commitRequisites() }
            }
            .disabled(model.receiverName.isEmpty || model.account.filter(\.isNumber).count < 8)
        }
    }

    private var abroadRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Перевод за рубеж", "Через ЭПР — в ₽ или стейблами (§10.3). Комиссия 0% на Pro+.")
            Menu {
                ForEach(["Сербия", "Турция", "Армения", "ОАЭ", "Казахстан"], id: \.self) { c in
                    Button(c) { model.country = c }
                }
            } label: {
                HStack {
                    Text(model.country).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textSecondary)
                }
                .padding(Spacing.md)
                .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
            }
            field($model.receiverName, placeholder: "Получатель")
            field($model.iban, placeholder: "IBAN / SWIFT", mono: true)
            PrimaryButton(title: "Далее", icon: "arrow.right") {
                withAnimation(Motion.smooth) { model.commitAbroad() }
            }
            .disabled(model.iban.isEmpty)
        }
    }

    private var qrRecipient: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            stepHeader("Цифровой рубль", "Оплата по универсальному QR — без комиссии, кошелёк ЦБ-платформы.")
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(theme.elevated)
                    .frame(height: 220)
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 88, weight: .light))
                    .foregroundStyle(theme.textSecondary)
            }
            PrimaryButton(title: "Сканировать QR (демо)", icon: "qrcode") {
                withAnimation(Motion.smooth) { model.commitQR() }
            }
        }
    }

    // MARK: - Step 2 · Amount

    @ViewBuilder private var amountStep: some View {
        recipientChip

        if model.kind.isCrypto {
            Picker("", selection: $model.inputInRub) {
                Text(model.asset).tag(false)
                Text("₽").tag(true)
            }
            .pickerStyle(.segmented)
        }

        AmountEntry(
            text: $model.amountText,
            symbol: amountSymbol,
            secondary: amountSecondary,
            secondaryIsWarning: !model.kind.isCrypto && model.insufficientFunds,
            quickAmounts: model.kind.isCrypto ? [] : [1_000, 5_000, 10_000],
            onQuick: { model.addAmount($0) }
        )

        if model.kind.isCrypto && model.insufficientFunds {
            inlineWarning("Недостаточно \(model.asset) на кошельке — спишется при поступлении.")
        }

        SourceAccountPicker(
            label: model.kind.isCrypto ? "Кошелёк" : "Счёт списания",
            selectedId: selectedSourceId,
            options: sourceOptions,
            onSelect: selectSource
        )

        gateView

        PrimaryButton(title: "Продолжить", icon: "arrow.right") {
            withAnimation(Motion.smooth) { model.goToConfirm() }
        }
        .disabled(!model.canProceed)
    }

    @ViewBuilder private var gateView: some View {
        switch model.gate {
        case .overLimit(let limit):
            LimitGateCard(kind: .perOperation(limit: limit), onAdjust: { model.amountText = "" })
        case .investorLimit(let remaining):
            LimitGateCard(kind: .investor(remaining: remaining),
                          onAdjust: { model.amountText = "" },
                          onTakeInvestorTest: { router.push(PaymentsRoute.investorStatus) })
        case .ok, .empty:
            EmptyView()
        }
    }

    // MARK: - Step 3 · Confirm

    @ViewBuilder private var confirmStep: some View {
        if let recipient = model.recipient {
            ConfirmSummaryCard(
                recipient: recipient,
                amount: confirmAmount,
                amountSymbol: confirmSymbol,
                fee: model.fee,
                feeLabel: model.kind.isCrypto ? "Комиссия сети (≈)" : "Комиссия",
                rubEquivalent: model.rubEquivalent,
                sourceTitle: sourceTitle,
                sourceSubtitle: sourceSubtitle,
                totalText: model.kind.isCrypto ? nil : money(model.totalDebitRub, "₽")
            )

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "\(model.kind.actionVerb) · \(bio.label)",
                              icon: bio.systemImage, isLoading: model.authorizing) {
                    Task { await model.authorize() }
                }
                Text("Подтверждение операции биометрией (§10.3)")
                    .font(BrandFont.micro)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Step 4 · Status

    private var statusStep: some View {
        OperationStatusView(
            outcome: model.outcome ?? .processing,
            amount: confirmAmount,
            currency: confirmSymbol,
            recipientName: model.recipient?.name ?? "Получатель",
            onRetry: { withAnimation(Motion.smooth) { model.retry() } },
            onClose: { router.popToRoot() }
        )
    }

    // MARK: - Shared pieces

    private var recipientChip: some View {
        Group {
            if let recipient = model.recipient {
                HStack(spacing: Spacing.md) {
                    Avatar(initials: recipient.initials, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipient.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        Text(recipient.detail).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    if let bank = recipient.bank { Badge(kind: .text(bank), tint: theme.accent) }
                }
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
            }
        }
    }

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text(subtitle).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func inlineWarning(_ text: String) -> some View {
        // DS ink variant for saturated status-as-text on a pale light surface (mirrors StatusPill);
        // no-op in the dark-only ship.
        let danger = theme.isDark ? theme.danger : BrandColors.dangerInkLight
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(danger)
            Text(text).font(BrandFont.caption).foregroundStyle(danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(_ binding: Binding<String>, placeholder: String = "",
                       keyboard: UIKeyboardType = .default, mono: Bool = false) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(keyboard)
            .font(mono ? BrandFont.mono(17) : BrandFont.body())
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    // MARK: - Derived values

    private var amountSymbol: String {
        if model.kind.isCrypto { return model.inputInRub ? "₽" : model.asset }
        return model.sourceAccount?.symbol ?? "₽"
    }

    private var amountSecondary: String {
        if model.kind.isCrypto {
            return model.inputInRub
                ? "≈ \(plain(model.assetAmount)) \(model.asset)"
                : "≈ \(money(model.rubAmount, "₽")) по курсу"
        }
        return model.insufficientFunds
            ? "Недостаточно средств на счёте"
            : "Доступно: \(money(model.availableBalance, model.sourceSymbol))"
    }

    private var confirmAmount: Double { model.kind.isCrypto ? model.assetAmount : model.rubAmount }
    private var confirmSymbol: String { model.kind.isCrypto ? model.asset : "₽" }

    private var sourceTitle: String {
        if model.kind.isCrypto { return "\(model.asset) кошелёк" }
        return model.sourceAccount?.displayTitle ?? "—"
    }
    private var sourceSubtitle: String {
        if model.kind.isCrypto {
            return "·· \(model.sourceWallet?.address.suffix(4) ?? "") · \(model.asset)"
        }
        return model.sourceAccount?.displaySubtitle ?? ""
    }

    private var selectedSourceId: String {
        model.kind.isCrypto ? (model.sourceWallet?.id ?? "") : (model.sourceAccount?.id ?? "")
    }

    private var sourceOptions: [SourceAccountPicker.Option] {
        if model.kind.isCrypto {
            return model.wallets.map { w in
                .init(id: w.id, icon: "bitcoinsign.circle.fill", title: "\(w.asset) кошелёк",
                      subtitle: "·· \(w.address.suffix(4))", balanceText: "\(plain(w.balance)) \(w.asset)")
            }
        }
        let sources = model.kind == .betweenAccounts
            ? model.eligibleSources.filter { $0.id != model.destinationAccount?.id }
            : model.eligibleSources
        return sources.map { a in
            .init(id: a.id, icon: a.type.paymentsIcon, title: a.displayTitle,
                  subtitle: a.displaySubtitle, balanceText: money(a.balance, a.symbol))
        }
    }

    private func selectSource(_ id: String) {
        if model.kind.isCrypto {
            model.sourceWallet = model.wallets.first { $0.id == id }
        } else {
            model.sourceAccount = model.accounts.first { $0.id == id }
        }
    }

    private func money(_ value: Double, _ symbol: String) -> String {
        (Self.formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " " + symbol
    }
    private func plain(_ value: Double) -> String {
        (Self.preciseFormatter.string(from: NSNumber(value: value)) ?? "\(value)")
    }
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 0
        return f
    }()
    private static let preciseFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 6; f.minimumFractionDigits = 0
        return f
    }()
}
