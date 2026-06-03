import SwiftUI

/// Generic biller hub for the three quick tiles (§9.2): Мои платежи · Счета ЖКУ · Штрафы ГАИ. Lists
/// the section's billers; tapping one opens the prefilled payment flow via ``PaymentsRoute/payBiller``.
struct BillerListView: View {
    let section: BillerSection

    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    private var billers: [Biller] { PaymentsMockData.billers(for: section) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(section.blurb)
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(billers.enumerated()), id: \.element.id) { index, biller in
                            Button { router.push(PaymentsRoute.payBiller(billerId: biller.id)) } label: {
                                ListRow(icon: biller.icon, iconTint: tint(biller),
                                        title: biller.name, subtitle: biller.detail,
                                        value: biller.suggestedAmount.map(Self.rub), showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            if index < billers.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tint(_ biller: Biller) -> Color? {
        biller.tintHex.map { Color(hex: $0) }
    }

    static func rub(_ value: Double) -> String {
        (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " ₽"
    }
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 0
        return f
    }()
}
