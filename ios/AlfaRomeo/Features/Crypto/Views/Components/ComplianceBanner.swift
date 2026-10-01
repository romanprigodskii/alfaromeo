import SwiftUI

/// Soft crypto-compliance note (§2.4): BTC/ETH/TON + стейблы, no anonymous coins. Informative, never
/// a wall. Applies to **crypto** only — ЦФА (the legal path) is never gated by it. Optional tap opens
/// the investor status / limits screen.
struct ComplianceBanner: View {
    var onInvestorStatus: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Комплаенс крипты")
                .font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
            Text(CryptoCatalog.complianceNote)
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onInvestorStatus {
                Button("Статус инвестора и лимиты", action: onInvestorStatus)
                    .font(BrandFont.subheadline.weight(.medium))
                    .foregroundStyle(theme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
