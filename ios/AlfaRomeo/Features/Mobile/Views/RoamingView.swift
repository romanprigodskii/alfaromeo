import SwiftUI

/// Роуминг Ромео Mobile (§7.1). On the безлимит (Infinite) tariff роуминг включён по умолчанию и не
/// выключается; на пакетах S/M он управляется тумблером и оплачивается отдельно. The §7.1 hook is a
/// prominent крипто-оплата entry: «оплатить роуминг криптой/стейблами в путешествии» — a deep-link
/// into the crypto-first payment flow (``MobileRoute/payment(_:)`` with ``MobilePaymentPurpose/roaming``),
/// styled with the cold crypto accent so it reads as the recommended way to pay while travelling.
struct RoamingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var tariff: MobileTariff { MobileTariff.make(for: effectiveTier) }

    /// Страны для поездок с ориентировочной ценой роуминга за день (§7.1 demo).
    private let countries: [(name: String, icon: String, perDay: String)] = [
        ("Турция", "airplane", "≈ 350 ₽/день"),
        ("ОАЭ", "airplane", "≈ 590 ₽/день"),
        ("Грузия", "airplane", "≈ 290 ₽/день"),
        ("Таиланд", "airplane", "≈ 640 ₽/день"),
        ("Сербия", "airplane", "≈ 320 ₽/день"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                statusCard
                cryptoPayCard
                countriesCard

                Text("Цены ориентировочные и зависят от страны и оператора-партнёра (§7.1).")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Роуминг")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: store.roamingEnabled)
        .animation(reduceMotion ? nil : Motion.snappy, value: effectiveTier)
        .task { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusCard: some View {
        SurfaceCard {
            if tariff.isUnlimited {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "airplane")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text("Роуминг").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Spacer(minLength: Spacing.sm)
                        StatusPill(status: .success, text: "Включён")
                    }
                    Text("Роуминг включён на тарифе Infinite (§7.1).")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Toggle(isOn: roamingBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Роуминг").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                            Text("Тариф \(tariff.name)").font(BrandFont.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .tint(theme.accent)

                    Text("На пакетах S и M роуминг оплачивается отдельно — включите его перед поездкой (§7.1).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var roamingBinding: Binding<Bool> {
        Binding(get: { store.roamingEnabled }, set: { store.setRoaming($0) })
    }

    // MARK: - Crypto pay (§7.1 hook)

    private var cryptoPayCard: some View {
        NavigationLink(value: MobileRoute.payment(.roaming)) {
            SurfaceCard {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Оплатить роуминг криптой/стейблами")
                            .font(BrandFont.bodyM.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Оплата стейблами прямо в поездке")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(theme.accentCrypto.first ?? theme.accent, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Countries

    private var countriesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Популярные направления").font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(countries.enumerated()), id: \.element.name) { i, country in
                        ListRow(icon: country.icon, title: country.name, value: country.perDay)
                        if i < countries.count - 1 { Divider().overlay(theme.border) }
                    }
                }
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
