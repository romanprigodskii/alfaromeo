import SwiftUI

/// «Заплатить поставщику» (§8.3): счёт/реквизиты → проверка → подтверждение → статус, with the
/// multi-step signing gate (§11.8). Below the threshold one biometric executes; above it the
/// biometric places the **first** signature and the payment is routed to «на подпись» for a second
/// signer. Driven by ``SupplierPaymentModel``; uses the graphite business theme.
struct SupplierPaymentView: View {
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var model = SupplierPaymentModel()
    private let bio = BiometricAuthenticator.available()

    var body: some View {
        Group {
            switch model.step {
            case .details: scroll { detailsStep }
            case .review:  scroll { reviewStep }
            case .status:  statusStep
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Платёж поставщику")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.step != .details)
        .toolbar {
            if model.step == .review {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation(Motion.smooth) { model.backToDetails() } } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .animation(Motion.smooth, value: model.step)
        .task { await model.load(api: api, session: session) }
    }

    private func scroll<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) { content() }
                .padding(Spacing.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    // MARK: Step 1 · детали

    @ViewBuilder private var detailsStep: some View {
        stepHeader("Кому платим", "Выберите контрагента или введите реквизиты.")

        Picker("", selection: $model.mode) {
            ForEach(SupplierPaymentModel.RecipientMode.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)

        if model.mode == .counterparty { counterpartyPicker } else { requisitesFields }

        stepHeader("Сумма и назначение", "")
        TextField("0", text: $model.amountText)
            .keyboardType(.numberPad)
            .font(BrandFont.body(28, weight: .semibold)).monospacedDigit()
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))

        thresholdHint
        field($model.purpose, placeholder: "Назначение платежа")

        PrimaryButton(title: "Проверить") {
            withAnimation(Motion.smooth) { model.goToReview() }
        }
        .disabled(!model.canProceedDetails)
    }

    private var counterpartyPicker: some View {
        SurfaceCard(padding: Spacing.sm) {
            if model.counterparties.isEmpty {
                Text("Справочник контрагентов пуст. Введите платёж по реквизитам.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.counterparties.enumerated()), id: \.element.id) { index, cp in
                        if index > 0 { Divider().overlay(theme.border) }
                        Button { model.selectedCounterpartyId = cp.id } label: {
                            HStack(spacing: Spacing.md) {
                                Avatar(initials: initials(cp.name), size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cp.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                                    Text("ИНН \(cp.inn)").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: model.selectedCounterpartyId == cp.id ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(model.selectedCounterpartyId == cp.id ? theme.accent : theme.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, Spacing.xs).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var requisitesFields: some View {
        VStack(spacing: Spacing.md) {
            field($model.freeName, placeholder: "Получатель (организация / ИП)")
            field($model.freeInn, placeholder: "ИНН", keyboard: .numberPad, mono: true)
            field($model.freeAccount, placeholder: "Расчётный счёт", keyboard: .numberPad, mono: true)
        }
    }

    @ViewBuilder private var thresholdHint: some View {
        if model.amount > 0 {
            let multi = model.requiresMultiSignature
            HStack(spacing: Spacing.sm) {
                Image(systemName: multi ? "signature" : "checkmark.shield")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.accent)
                Text(multi
                     ? "Свыше \(SupplierPaymentModel.rub(model.threshold)) нужна вторая подпись."
                     : "До \(SupplierPaymentModel.rub(model.threshold)) хватит одной подписи.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Step 2 · проверка

    @ViewBuilder private var reviewStep: some View {
        stepHeader("Проверка", "Проверьте получателя и сумму.")
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Avatar(initials: initials(model.supplierName), size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.supplierName).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text(model.supplierDetail).font(BrandFont.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                }
                AmountText(amount: model.amount, currency: "₽", size: 36)
                SurfaceCard(padding: Spacing.sm, elevated: true) {
                    VStack(spacing: 0) {
                        reviewRow("Назначение", model.purpose.isEmpty ? "Оплата поставщику" : model.purpose)
                        Divider().overlay(theme.border)
                        reviewRow("Списание", model.sourceTitle)
                    }
                }
            }
        }

        signingBanner
        if model.insufficientFunds && !model.requiresMultiSignature { insufficientWarning }

        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: model.requiresMultiSignature
                          ? "Подписать и отправить · \(bio.label)"
                          : "Оплатить · \(bio.label)",
                          icon: bio.systemImage, isLoading: model.authorizing) {
                Task { await model.authorize() }
            }
            Text(model.requiresMultiSignature
                 ? "Ваша подпись первая из \(Int(TeamStore.shared.policy.requiredSigners)). Подтверждение биометрией."
                 : "Подтверждение операции биометрией.")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var signingBanner: some View {
        if model.requiresMultiSignature {
            SurfaceCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "signature").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Нужна вторая подпись").font(BrandFont.bodyM.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Text("Сумма больше порога \(SupplierPaymentModel.rub(model.threshold)). После вашей подписи платёж уйдёт на подпись\(model.nextSignerName.map { ": \($0)" } ?? " второму лицу").")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var insufficientWarning: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.isDark ? theme.danger : BrandColors.dangerInkLight)
            Text("Недостаточно средств на счёте.")
                .font(BrandFont.caption).foregroundStyle(theme.isDark ? theme.danger : BrandColors.dangerInkLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Step 3 · статус

    @ViewBuilder private var statusStep: some View {
        switch model.result {
        case .routedForSignature:
            routedStatus
        case .executed(let outcome):
            OperationStatusView(outcome: outcome, amount: model.amount, currency: "₽",
                                recipientName: model.supplierName,
                                onRetry: { withAnimation(Motion.smooth) { model.retry() } },
                                onClose: { router.popToRoot() })
        case .none:
            EmptyView()
        }
    }

    private var routedStatus: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.lg)
            ZStack {
                Circle().fill(theme.fill).frame(width: 96, height: 96)
                Image(systemName: "signature").font(.system(size: 40, weight: .regular)).foregroundStyle(theme.textPrimary)
            }
            VStack(spacing: Spacing.sm) {
                Text("Отправлено на подпись").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("Вы поставили первую подпись. Платёж ждёт второй подписи\(model.nextSignerName.map { ": \($0)" } ?? "").")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.screen)
            }
            if let item = model.submitted {
                SurfaceCard { SignatureProgressView(slots: item.slots) }
            }
            Spacer(minLength: Spacing.md)
            VStack(spacing: Spacing.sm) {
                if let item = model.submitted {
                    PrimaryButton(title: "К подписи второго лица") {
                        router.push(TeamRoute.approvalDetail(approvalId: item.id))
                    }
                }
                SecondaryButton(title: "Готово") { router.popToRoot() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.screen)
        .background(theme.background.ignoresSafeArea())
    }

    // MARK: Helpers

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            if !subtitle.isEmpty {
                Text(subtitle).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func field(_ binding: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default, mono: Bool = false) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(keyboard)
            .font(mono ? BrandFont.code(17) : BrandFont.body())
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "?" : parts.map(String.init).joined().uppercased()
    }
}
