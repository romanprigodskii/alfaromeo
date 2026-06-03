import SwiftUI

/// Кредиты — the credit storefront (§9.1, §10.5). The витрина: a pre-approved limit hero with an
/// explainable «почему столько», a shelf of products (наличные / карта / рассрочка) showing each
/// product's personalised limit + rate, the current obligations that drive ПДН, and any credits
/// opened in the flow.
///
/// Public entry point: this view is what `HomeRoute.credits` should resolve to. The single remaining
/// integration step is the one-line seam in Home — `case .credits: CreditView()` in
/// `HomeRoute.destination` (still pending; owned by Home, same convention as the Crypto/Savings hubs).
/// The hub itself is fully self-contained: it registers its own sub-routes via
/// `.navigationDestination(for: CreditRoute.self)`, so no further Credit-side wiring is needed.
struct CreditView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = CreditStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                hero
                productsSection
                obligationsSection
                if !store.openedCredits.isEmpty { activeSection }
                disclaimer
            }
            .padding(Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Кредиты")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: CreditRoute.self) { $0.destination }
        .creditExitToolbar()
        .task(id: profileId) { store.load(profileId: profileId) }
    }

    // MARK: Hero — preapproved limit + explainable entry

    private var hero: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                StatusPill(status: .success, text: "Преодобрено")
                Spacer()
            }
            LimitGauge(
                title: "Вам предодобрено",
                amount: store.heroLimit,
                ceiling: CreditCatalog.primary.maxAmount,
                rateLabel: "≈ \(CreditFormat.percent(store.personalRate(for: CreditCatalog.primary)))")
            SecondaryButton(title: "Почему такая сумма?", icon: "sparkles") {
                router.push(CreditRoute.prequal)
            }
        }
    }

    // MARK: Product shelf (§10.5 наличные / карта / рассрочка)

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Кредитные продукты", subtitle: "Ставка и лимит — под ваш профиль")
            ForEach(CreditCatalog.products) { product in
                CreditProductCard(
                    product: product,
                    approvedLimit: store.approvedLimit(for: product),
                    rate: store.personalRate(for: product)
                ) { router.push(CreditRoute.apply(productId: product.id)) }
            }
        }
    }

    // MARK: Current obligations → ПДН (and the simulator's «close X» levers)

    private var obligationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Текущие обязательства", subtitle: "Влияют на лимит через долговую нагрузку")
            SurfaceCard(padding: Spacing.xs) {
                VStack(spacing: 0) {
                    ForEach(store.obligations) { ob in
                        obligationRow(ob)
                        if ob.id != store.obligations.last?.id { Divider().overlay(theme.border) }
                    }
                }
            }
            HStack(spacing: Spacing.xs) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent").foregroundStyle(theme.warning)
                Text("ПДН \(Int((store.dti() * 100).rounded()))% · платежи \(CreditFormat.rub(store.baseInputs.monthlyDebt))/мес")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                Spacer()
            }
            SecondaryButton(title: "Открыть симулятор", icon: "slider.horizontal.3") {
                router.push(CreditRoute.prequal)
            }
        }
    }

    private func obligationRow(_ ob: Obligation) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(theme.elevated).frame(width: 36, height: 36)
                Image(systemName: ob.kind.systemImage).font(.system(size: 15)).foregroundStyle(theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(ob.lender).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                Text("остаток \(CreditFormat.rub(ob.balance))").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(CreditFormat.rub(ob.monthlyPayment))/мес")
                    .font(BrandFont.mono(14, weight: .medium)).foregroundStyle(theme.textPrimary)
                if !ob.kind.isClosableLever {
                    Text("обеспеченный").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
    }

    // MARK: Opened credits (demo)

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Мои кредиты")
            SurfaceCard(padding: Spacing.xs) {
                VStack(spacing: 0) {
                    ForEach(store.openedCredits) { credit in
                        HStack(spacing: Spacing.sm) {
                            ZStack {
                                Circle().fill(theme.accent.opacity(0.14)).frame(width: 36, height: 36)
                                Image(systemName: credit.kind.systemImage).font(.system(size: 15)).foregroundStyle(theme.accent)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(credit.kind.title).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                                Text("\(CreditFormat.rub(credit.monthlyPayment))/мес · \(CreditFormat.term(credit.termMonths))")
                                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            AmountText(amount: credit.amount, size: 17)
                        }
                        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
                        if credit.id != store.openedCredits.last?.id { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Не является публичной офертой. Итоговые условия определяются по результатам рассмотрения заявки. Демо-расчёт.")
            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.md)
    }

    // MARK: Building blocks

    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            if let subtitle {
                Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        CreditView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.theme, .default)
    .environment(Router())
}
