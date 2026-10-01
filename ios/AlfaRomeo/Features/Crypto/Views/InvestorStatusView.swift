import SwiftUI

/// Статус инвестора / лимиты (§9.6 / §2.4) — the crypto compliance surface. Shows квал/неквал status,
/// the risk-test gate, the 300к ₽/year limit progress, and the asset allow-list. This applies to
/// **crypto** only; ЦФА (the legal path) is exempt and that's stated here too.
struct InvestorStatusView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var showRiskTest = false

    private var status: InvestorStatus { session.currentUser?.investorStatus ?? .unqualified }
    private var unqualified: Bool { status == .unqualified }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                statusCard
                if unqualified {
                    riskTestCard
                    limitCard
                }
                allowListCard
                cfaExemptNote
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Статус инвестора")
        .navigationBarTitleDisplayMode(.inline)
        .bottomSheet(isPresented: $showRiskTest, detents: [.large]) {
            RiskTestSheet(onPass: { store.passRiskTest(); showRiskTest = false },
                          onCancel: { showRiskTest = false })
        }
    }

    private var statusCard: some View {
        HStack(spacing: Spacing.md) {
            GlyphCircle(systemImage: unqualified ? "person.fill.questionmark" : "checkmark.seal", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(unqualified ? "Неквалифицированный инвестор" : "Квалифицированный инвестор")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(unqualified ? "Лимит \(CryptoFormat.rub(CryptoCompliance.yearlyLimitRub)) в год" : "Без лимитов на крипто-операции")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
    }

    private var riskTestCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GroupedSection("Тест на риски",
                           footer: "Обязателен перед первой крипто-сделкой для неквал-инвесторов. ЦФА не касается.") {
                HStack {
                    Text("Статус").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Spacer()
                    StatusPill(status: store.riskTestPassed ? .success : .warning,
                               text: store.riskTestPassed ? "Пройден" : "Не пройден")
                }
                .padding(.vertical, Spacing.rowVertical)
            }
            if !store.riskTestPassed {
                PrimaryButton(title: "Пройти тест") { showRiskTest = true }
            }
        }
    }

    private var limitCard: some View {
        GroupedSection("Годовой лимит",
                       footer: "Лимит \(CryptoFormat.rub(CryptoCompliance.yearlyLimitRub)) в год через посредника. Статус квалифицированного инвестора (порог 24 млн ₽) снимает лимит.") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ProgressBar(value: store.investorUsedRub / CryptoCompliance.yearlyLimitRub)
                HStack {
                    Text("Использовано \(CryptoFormat.rub(store.investorUsedRub))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("Осталось \(CryptoFormat.rub(store.investorRemainingRub))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                }
                .monospacedDigit()
            }
            .padding(.vertical, Spacing.rowVertical)
        }
    }

    private var allowListCard: some View {
        GroupedSection("Что разрешено") {
            bullet("checkmark", theme.statusInk(.success), "BTC, ETH, TON и стейблкоины (USDT, USDC)")
            bullet("xmark", theme.statusInk(.danger), "Анонимные монеты (Monero, Zcash) запрещены")
            bullet("checkmark", theme.statusInk(.success), "Цифровой рубль и ЦФА без крипто-лимитов")
        }
    }

    private var cfaExemptNote: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            LegalBadge(compact: true)
            Text("ЦФА: легальный путь по 259-ФЗ. Лимиты и тест на риски крипты к нему не применяются, только обычный KYC.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                .frame(width: 20)
            Text(text).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(20 + Spacing.sm)
    }
}

#Preview {
    NavigationStack {
        InvestorStatusView()
            .environment(AppSession.mockAuthenticated())
            .environment(\.theme, .default)
    }
}
