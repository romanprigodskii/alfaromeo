import SwiftUI

/// Component #4 — the crypto-acquiring proof: shows стейбл → ₽ auto-conversion
/// at the LIVE rate (§2.4). Numbers are monospacedDigit so they animate cleanly
/// as the live rate ticks.
struct CryptoConversionCard: View {
    @Environment(\.theme) private var theme

    let asset: String
    let stableAmount: Double
    let rate: Double
    let creditedRub: Double
    let isLive: Bool

    private var creditedTint: Color { theme.accentCrypto.first ?? theme.accent }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                stablePays
                arrow
                creditedToAccount
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text("Авто-конвертация в ₽")
                .font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
            Spacer(minLength: Spacing.sm)
            livePill
        }
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text(isLive ? "live-курс" : "курс")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    // MARK: - Rows

    private var stablePays: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Клиент платит")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
            Text(CryptoFormat.qty(stableAmount, symbol: asset))
                .font(BrandFont.mono(22))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("по курсу 1 \(asset) = \(CryptoFormat.rub(rate, fraction: 2))")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(theme.cryptoGradient)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var creditedToAccount: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Зачислится на счёт")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
            Text(CryptoFormat.rub(creditedRub))
                .font(BrandFont.mono(22))
                .foregroundStyle(creditedTint)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Preview

private struct CryptoConversionCard_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            CryptoConversionCard(
                asset: "USDT",
                stableAmount: 142.3456,
                rate: 96.42,
                creditedRub: 13721,
                isLive: true
            )
            CryptoConversionCard(
                asset: "USDC",
                stableAmount: 50,
                rate: 96.18,
                creditedRub: 4809,
                isLive: false
            )
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
    }
}

#Preview {
    CryptoConversionCard_PreviewHost()
        .environment(\.theme, .default)
}
