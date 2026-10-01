import SwiftUI

/// Роуминг Ромео Mobile (§7.1). On the безлимит (Infinite) tariff роуминг включён по умолчанию и не
/// выключается; на пакетах S/M он управляется тумблером и оплачивается отдельно. The §7.1 hook is a
/// prominent крипто-оплата entry: «оплатить роуминг криптой/стейблами в путешествии» — a deep-link
/// into the crypto-first payment flow (``MobileRoute/payment(_:)`` with ``MobilePaymentPurpose/roaming``),
/// shown as a row right under the roaming switch.
struct RoamingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var tariff: MobileTariff { MobileTariff.make(for: effectiveTier) }

    /// Страны для поездок с ориентировочной ценой роуминга за день, ₽ (§7.1 demo).
    private let countries: [(name: String, perDay: Double)] = [
        ("Турция", 350),
        ("ОАЭ", 590),
        ("Грузия", 290),
        ("Таиланд", 640),
        ("Сербия", 320),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                statusSection
                countriesSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Роуминг")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: store.roamingEnabled)
        .animation(reduceMotion ? nil : Motion.snappy, value: effectiveTier)
        .task { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Status + crypto pay (§7.1 hook)

    private var statusSection: some View {
        GroupedSection(footer: tariff.isUnlimited
                       ? "На классе Infinite роуминг включён всегда."
                       : "На пакетах S и M роуминг оплачивается отдельно. Включите его перед поездкой.") {
            if tariff.isUnlimited {
                HStack(spacing: ListRow.glyphSpacing) {
                    GlyphCircle(systemImage: "airplane")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Роуминг").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Text("Тариф \(tariff.name)").font(BrandFont.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    StatusPill(status: .success, text: "Включён")
                }
                .frame(minHeight: Spacing.rowMinHeightTwoLine)
                .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
            } else {
                HStack(spacing: ListRow.glyphSpacing) {
                    GlyphCircle(systemImage: "airplane")
                    Toggle(isOn: roamingBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Роуминг").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            Text("Тариф \(tariff.name)").font(BrandFont.subheadline)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .tint(theme.accent)
                }
                .frame(minHeight: Spacing.rowMinHeightTwoLine)
                .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
            }

            NavigationLink(value: MobileRoute.payment(.roaming)) {
                ListRow(icon: "bitcoinsign", title: "Оплата криптой",
                        subtitle: "Криптовалюта и стейблкоины", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    private var roamingBinding: Binding<Bool> {
        Binding(get: { store.roamingEnabled }, set: { store.setRoaming($0) })
    }

    // MARK: - Countries

    private var countriesSection: some View {
        GroupedSection("Популярные направления",
                       footer: "Цены ориентировочные и зависят от страны и оператора-партнёра.") {
            ForEach(countries, id: \.name) { country in
                ListRow(title: country.name,
                        value: "≈\u{00A0}" + MoneyFormat.fiat(country.perDay) + " в день")
            }
        }
    }
}

// MARK: - Preview

private struct RoamingPreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            RoamingView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Роуминг · Pro (Пакет M)") {
    RoamingPreviewHost(session: .mockAuthenticated())
}

#Preview("Роуминг · Infinite (включён)") {
    let session = AppSession.mockAuthenticated()
    if let p = session.activeProfile { session.setTier(.infinite, for: p.id) }
    return RoamingPreviewHost(session: session)
}
