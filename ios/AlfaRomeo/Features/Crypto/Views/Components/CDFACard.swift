import SwiftUI

/// A ЦФА instrument card for the catalog (§9.6 🆕). Surfaces эмитент + оператор (the registered ИС),
/// price in ₽, доходность, and the legal stamp. The cold gradient ties it to the digital-asset family;
/// the ``LegalBadge`` marks it as the regulated path (no crypto квал/неквал gating, §2.4).
struct CDFACard: View {
    let cdfa: CDFA
    var holdingUnits: Double = 0
    var onTap: () -> Void = {}

    @Environment(\.theme) private var theme

    private var owned: Bool { holdingUnits > 0 }

    var body: some View {
        Button(action: onTap) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.md) {
                        AssetGlyph(symbol: cdfa.ticker, systemImage: cdfa.category.icon, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cdfa.name)
                                .font(BrandFont.bodyM.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            Text("\(cdfa.category.label) · \(cdfa.ticker)")
                                .font(BrandFont.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer(minLength: Spacing.sm)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CryptoFormat.rub(cdfa.priceRub, fraction: 0))
                                .font(BrandFont.amountS)
                                .foregroundStyle(theme.textPrimary)
                                .monospacedDigit()
                            Text(CryptoFormat.pct(cdfa.dayChangePct))
                                .font(BrandFont.micro.weight(.semibold))
                                .foregroundStyle(cdfa.dayChangePct >= 0 ? theme.success : theme.danger)
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        infoChip(icon: "building.2", text: cdfa.issuer)
                        infoChip(icon: "server.rack", text: cdfa.operatorName)
                    }

                    HStack(spacing: Spacing.sm) {
                        LegalBadge(compact: true)
                        if cdfa.yieldPct > 0 {
                            Text(cdfa.yieldLabel)
                                .font(BrandFont.caption.weight(.semibold))
                                .foregroundStyle(theme.success)
                        }
                        Spacer()
                        if owned {
                            Text("В портфеле: \(CryptoFormat.qty(holdingUnits))")
                                .font(BrandFont.micro.weight(.medium))
                                .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(BrandFont.micro).lineLimit(1)
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
        .background(theme.elevated, in: Capsule())
    }
}

#Preview {
    CDFACard(cdfa: MockCryptoData.cdfas[1], holdingUnits: 40)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
