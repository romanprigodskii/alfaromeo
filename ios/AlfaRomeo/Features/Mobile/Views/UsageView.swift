import SwiftUI

/// Детализация / использование Ромео Mobile (§7.2). A read-only breakdown of the consumed пакет —
/// по дням и по категориям — derived deterministically from the plan via ``MobileStore/usage()``
/// (mock-метеринг, §7.3). The totals here always match the hub's «израсходовано», since both read
/// the same `usedGb`/`usedMin`. No mutations: this screen only visualises what the store already knows.
struct UsageView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        let usage = store.usage()

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                summary(usage)

                UsageBreakdownView(usage: usage)

                Text("Демо-данные. В рабочей версии детализацию передаёт оператор по факту трафика.")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Использование")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.smooth, value: usage.totalGb)
        .task { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Summary

    private func summary(_ usage: MobileUsage) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Израсходовано за 7 дней").font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: Spacing.lg) {
                    totalColumn(value: MobileTariff.format(usage.totalGb) + "\u{00A0}ГБ", label: "Интернет")
                    Hairline(axis: .vertical).frame(height: 40)
                    totalColumn(value: MoneyFormat.integer(usage.totalMinutes) + "\u{00A0}мин", label: "Звонки")
                }

                Text("Пик за день: " + MobileTariff.format(usage.peakGb) + "\u{00A0}ГБ")
                    .font(BrandFont.footnote).monospacedDigit().foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func totalColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value).font(BrandFont.title2).monospacedDigit()
                .foregroundStyle(theme.textPrimary)
            Text(label).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

private struct UsagePreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            UsageView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Использование") {
    UsagePreviewHost(session: .mockAuthenticated())
}
