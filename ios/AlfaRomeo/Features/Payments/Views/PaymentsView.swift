import SwiftUI

/// Платежи — transfers & payments hub root (§9.2). A quick-action row (Оплата / Мои платежи / ЖКУ /
/// Штрафы), the seven transfer rails, supplier payments + templates, and the offers as plain rows.
/// Every rail pushes the unified ``TransferFlowView`` via ``PaymentsRoute``; the section title + chrome
/// are owned by the surrounding ``SectionScaffold``.
struct PaymentsView: View {
    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme

    @State private var model = PaymentsHubModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                quickActions
                transfers
                more
                offers
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationDestination(for: PaymentsRoute.self) { $0.destination }
        .task { await model.load(api: api, session: session) }
    }

    // MARK: Quick actions (§9.2): «Оплата» (QR / NFC / СБП / цифровой ₽) + the three biller hubs

    private var quickActions: some View {
        QuickActionRow {
            QuickActionButton("Оплата", systemImage: "qrcode.viewfinder") {
                router.push(PaymentsRoute.pay)
            }
            ForEach(model.sections) { section in
                QuickActionButton(shortTitle(for: section), systemImage: section.icon) {
                    router.push(PaymentsRoute.section(section))
                }
            }
        }
    }

    private func shortTitle(for section: BillerSection) -> String {
        switch section {
        case .myPayments: return "Мои платежи"
        case .utilities:  return "ЖКУ"
        case .fines:      return "Штрафы"
        }
    }

    // MARK: Transfers (§9.2 / §10.3, seven rails)

    private var transfers: some View {
        GroupedSection("Переводы") {
            ForEach(model.rails) { kind in
                Button { router.push(PaymentsRoute.transfer(kind)) } label: {
                    ListRow(icon: kind.icon, title: kind.title, subtitle: kind.subtitle, showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: Suppliers + templates

    private var more: some View {
        GroupedSection("Другие платежи") {
            Button { router.push(PaymentsRoute.suppliers) } label: {
                ListRow(icon: "magnifyingglass", title: "Поставщики",
                        subtitle: "Поиск по названию и ИНН", showsChevron: true)
            }
            .buttonStyle(.row)
            Button { router.push(PaymentsRoute.templates) } label: {
                ListRow(icon: "square.stack.3d.up", title: "Шаблоны и автоплатежи",
                        subtitle: templatesSummary, showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    private var templatesSummary: String {
        let t = model.templates.count
        let a = PaymentsMockData.autopayments.count
        return "\(t) \(Self.plural(t, "шаблон", "шаблона", "шаблонов")), "
            + "\(a) \(Self.plural(a, "автоплатёж", "автоплатежа", "автоплатежей"))"
    }

    // MARK: Offers (plain rows; slogans removed)

    private var offers: some View {
        GroupedSection("Предложения") {
            ForEach(model.offers) { offer in
                Button { open(offer) } label: {
                    ListRow(icon: offer.icon, title: offer.title, subtitle: offer.subtitle, showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    /// Route offers straight into the matching rail (demo affordance).
    private func open(_ offer: PaymentOffer) {
        switch offer.id {
        case "o1": router.push(PaymentsRoute.transfer(.abroad))
        case "o4": router.push(PaymentsRoute.section(.utilities))   // «Кэшбек на ЖКУ» → начисления ЖКУ
        default:   break
        }
    }

    private static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }
}
