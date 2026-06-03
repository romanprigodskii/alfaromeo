import SwiftUI

/// Платежи — transfers & payments hub root (§9.2). Quick tiles (Мои платежи / Счета ЖКУ / Штрафы),
/// the offers banner, the seven transfer rails, supplier payments, and templates/autopayments. Every
/// rail pushes the unified ``TransferFlowView`` via ``PaymentsRoute``; the section title + chrome are
/// owned by the surrounding ``SectionScaffold``.
struct PaymentsView: View {
    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme

    @State private var model = PaymentsHubModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                quickTiles
                offers
                transfers
                more
            }
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationDestination(for: PaymentsRoute.self) { $0.destination }
        .task { await model.load(api: api, session: session) }
    }

    // MARK: Quick tiles (§9.2 «плитки»)

    private var quickTiles: some View {
        HStack(spacing: Spacing.md) {
            ForEach(model.sections) { section in
                QuickActionTile(icon: section.icon, title: section.title,
                                subtitle: subtitle(for: section), tint: tint(for: section)) {
                    router.push(PaymentsRoute.section(section))
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func subtitle(for section: BillerSection) -> String {
        switch section {
        case .myPayments: return "Сохранённые"
        case .utilities:  return "Начисления"
        case .fines:      return "По номеру авто"
        }
    }
    private func tint(for section: BillerSection) -> Color {
        switch section {
        case .myPayments: return theme.accent     // профиль-акцент
        case .utilities:  return theme.warning    // энергия/ЖКУ — янтарный
        case .fines:      return theme.danger     // штрафы — красный
        }
    }

    // MARK: Offers banner

    private var offers: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Предложения").padding(.horizontal, Spacing.lg)
            OffersBanner(offers: model.offers) { offer in
                // Route a couple of offers straight into the matching rail (demo affordance).
                switch offer.id {
                case "o2": router.push(PaymentsRoute.transfer(.cryptoToContact))
                case "o3": router.push(PaymentsRoute.transfer(.digitalRubleQR))
                case "o1": router.push(PaymentsRoute.transfer(.abroad))
                case "o4": router.push(PaymentsRoute.section(.utilities))   // «Кэшбек на ЖКУ» → начисления ЖКУ
                default:   break
                }
            }
        }
    }

    // MARK: Transfers (§9.2 / §10.3 — seven rails)

    private var transfers: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Переводы")
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(model.rails.enumerated()), id: \.element) { index, kind in
                        Button { router.push(PaymentsRoute.transfer(kind)) } label: {
                            ListRow(icon: kind.icon,
                                    iconTint: kind.usesCryptoGradient ? theme.accentCrypto.first : nil,
                                    title: kind.title, subtitle: kind.subtitle, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        if index < model.rails.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: Suppliers + templates

    private var more: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Платежи")
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    Button { router.push(PaymentsRoute.suppliers) } label: {
                        ListRow(icon: "magnifyingglass", title: "Платежи поставщикам",
                                subtitle: "Поиск по названию и категориям", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(theme.border)
                    Button { router.push(PaymentsRoute.templates) } label: {
                        ListRow(icon: "square.stack.3d.up", title: "Шаблоны и автоплатежи",
                                subtitle: "\(model.templates.count) шаблона · автоплатежи", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(BrandFont.micro).tracking(1.5)
            .foregroundStyle(theme.textSecondary)
    }
}
