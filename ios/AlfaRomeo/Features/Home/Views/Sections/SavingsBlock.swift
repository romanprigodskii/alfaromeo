import SwiftUI

/// Deposits & staking teaser (§9.1, §10.6). Shows total ₽ value + best APY. Opens the savings stub
/// (``HomeRoute.deposits``).
struct SavingsBlock: View {
    let dashboard: HomeDashboard
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        DashboardSection(title: "Вклады и стейкинг", actionTitle: "Открыть", action: onTap) {
            Button(action: onTap) {
                SurfaceCard {
                    HStack(alignment: .center, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("В работе").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            AmountText(amount: dashboard.depositsValueRub, size: 22)
                            HStack(spacing: Spacing.sm) {
                                ForEach(dashboard.deposits) { deposit in
                                    Badge(kind: .text(depositLabel(deposit)), tint: theme.accent)
                                }
                            }
                        }
                        Spacer()
                        if let apy = dashboard.bestDepositApy {
                            VStack(spacing: 0) {
                                Text(String(format: "%.1f%%", apy))
                                    .font(BrandFont.mono(20, weight: .semibold))
                                    .foregroundStyle(theme.success)
                                Text("до, годовых").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func depositLabel(_ deposit: Deposit) -> String {
        switch deposit.kind {
        case .ruble: return "Вклад ₽"
        case .stake: return "Стейкинг \(deposit.asset ?? "")"
        }
    }
}
