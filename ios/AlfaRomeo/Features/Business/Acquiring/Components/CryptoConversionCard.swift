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
            Text("Конвертация в ₽")
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
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Rows

    private var stablePays: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Клиент платит")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
            Text(MoneyFormat.crypto(stableAmount, symbol: asset))
                .font(BrandFont.body(22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("по курсу 1 \(asset) = \(MoneyFormat.fiat(rate))")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var creditedToAccount: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Зачислится на счёт")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
            Text(MoneyFormat.fiat(creditedRub.rounded()))
                .font(BrandFont.body(22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
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
