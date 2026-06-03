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
                cfaExemptCard
            }
            .padding(.horizontal, Spacing.lg)
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
        SurfaceCard {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle().fill(theme.cryptoGradient).frame(width: 48, height: 48)
                    Image(systemName: unqualified ? "person.fill.questionmark" : "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(unqualified ? "Неквалифицированный инвестор" : "Квалифицированный инвестор")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text(unqualified ? "Лимит 300 000 ₽/год · только BTC/ETH+стейблы" : "Без лимитов на крипто-операции")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var riskTestCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: store.riskTestPassed ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.riskTestPassed ? theme.success : theme.warning)
                    Text("Тест на риски").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    StatusPill(status: store.riskTestPassed ? .success : .warning,
                               text: store.riskTestPassed ? "Пройден" : "Не пройден")
                }
                Text("Обязателен перед первой крипто-сделкой для неквал-инвесторов (§2.4). ЦФА он не касается.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                if !store.riskTestPassed {
                    PrimaryButton(title: "Пройти тест", icon: "checkmark.shield") { showRiskTest = true }
                }
            }
        }
    }

    private var limitCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Годовой лимит").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                ProgressBar(value: store.investorUsedRub / CryptoCompliance.yearlyLimitRub, useCryptoGradient: true, height: 10)
                HStack {
                    Text("Использовано \(CryptoFormat.rub(store.investorUsedRub))")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("Осталось \(CryptoFormat.rub(store.investorRemainingRub))")
                        .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                Text("Лимит 300 000 ₽/год через посредника. Повысьте статус до квалифицированного (порог 24 млн ₽), чтобы снять лимит.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var allowListCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Что разрешено").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                bullet("checkmark.circle.fill", theme.success, "BTC, ETH и стейблкоины (USDT/USDC)")
                bullet("xmark.circle.fill", theme.danger, "Анонимные монеты (Monero, Zcash) — запрещены")
                bullet("checkmark.circle.fill", theme.success, "Цифровой рубль и ЦФА — без крипто-лимитов")
            }
        }
    }

    private var cfaExemptCard: some View {
        HStack(spacing: Spacing.sm) {
            LegalBadge(compact: true)
            Text("ЦФА — легальный путь по 259-ФЗ. Лимиты и тест на риски крипты к нему не применяются — только обычный KYC.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke((theme.accentCrypto.first ?? theme.accent).opacity(0.4), lineWidth: 1))
    }

    private func bullet(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            Text(text).font(BrandFont.callout).foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        InvestorStatusView()
            .environment(AppSession.mockAuthenticated())
            .environment(\.theme, .default)
    }
}
