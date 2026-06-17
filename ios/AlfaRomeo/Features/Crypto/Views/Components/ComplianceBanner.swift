import SwiftUI

/// Soft crypto-compliance note (§2.4): BTC/ETH/TON + стейблы, no anonymous coins. Informative, never
/// a wall. Applies to **crypto** only — ЦФА (the legal path) is never gated by it. Optional tap opens
/// the investor status / limits screen.
struct ComplianceBanner: View {
    var onInvestorStatus: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                Text("Комплаенс крипты")
                    .font(BrandFont.headline)
                    .foregroundStyle(theme.textPrimary)
            }
            Text(CryptoCatalog.complianceNote)
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onInvestorStatus {
                Button(action: onInvestorStatus) {
                    HStack(spacing: Spacing.xs) {
                        Text("Статус инвестора и лимиты")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(BrandFont.caption.weight(.semibold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke((theme.accentCrypto.first ?? theme.accent).opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ComplianceBanner(onInvestorStatus: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
