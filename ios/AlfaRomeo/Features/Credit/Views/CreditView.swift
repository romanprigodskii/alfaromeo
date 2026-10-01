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
            VStack(alignment: .leading, spacing: Spacing.section) {
                hero
                productsSection
                obligationsSection
                if !store.openedCredits.isEmpty { activeSection }
                disclaimer
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Кредиты")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: CreditRoute.self) { $0.destination }
        .creditExitToolbar()
        .task(id: profileId) { store.load(profileId: profileId) }
    }

    // MARK: Hero: preapproved limit + explainable entry

    private var hero: some View {
        LimitGauge(
            title: "Предодобрено",
            amount: store.heroLimit,
            ceiling: CreditCatalog.primary.maxAmount,
            rateLabel: "≈ \(CreditFormat.percent(store.personalRate(for: CreditCatalog.primary)))",
            actionTitle: "Почему такая сумма",
            action: { router.push(CreditRoute.prequal) })
    }

    // MARK: Product shelf (§10.5 наличные / карта / рассрочка)

    private var productsSection: some View {
        GroupedSection("Продукты") {
            ForEach(CreditCatalog.products) { product in
                CreditProductRow(
                    product: product,
                    approvedLimit: store.approvedLimit(for: product),
                    rate: store.personalRate(for: product)
                ) { router.push(CreditRoute.apply(productId: product.id)) }
            }
        }
    }

    // MARK: Current obligations → ПДН (and the simulator's «close X» levers)

    private var obligationsSection: some View {
        GroupedSection("Обязательства",
                       footer: "Платежи входят в долговую нагрузку и влияют на лимит. Обеспеченные кредиты в симуляторе не закрываются.") {
            ForEach(store.obligations) { ob in
                ListRow(icon: ob.kind.systemImage,
                        title: ob.lender,
                        subtitle: "\(CreditFormat.rub(ob.monthlyPayment))/мес, остаток \(CreditFormat.rub(ob.balance))")
            }
            Button { router.push(CreditRoute.prequal) } label: {
                ListRow(icon: "slider.horizontal.3",
                        title: "Долговая нагрузка",
                        subtitle: "Платежи \(CreditFormat.rub(store.baseInputs.monthlyDebt))/мес",
                        value: "ПДН \(MoneyFormat.percent(fraction: store.dti(), maxFractionDigits: 0))",
                        showsChevron: true)
            }
            .buttonStyle(.row)
            .accessibilityHint("Открыть симулятор лимита")
        }
    }

    // MARK: Opened credits (demo)

    private var activeSection: some View {
        GroupedSection("Мои кредиты") {
            ForEach(store.openedCredits) { credit in
                ListRow(icon: credit.kind.systemImage,
                        title: CreditCatalog.product(id: credit.productId)?.name ?? credit.kind.title,
                        subtitle: "\(CreditFormat.rub(credit.monthlyPayment))/мес · \(CreditFormat.term(credit.termMonths))",
                        value: CreditFormat.rub(credit.amount))
            }
        }
    }

    private var disclaimer: some View {
        Text("Не является публичной офертой. Итоговые условия определяются по результатам рассмотрения заявки. Демо-расчёт.")
            .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.md)
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
