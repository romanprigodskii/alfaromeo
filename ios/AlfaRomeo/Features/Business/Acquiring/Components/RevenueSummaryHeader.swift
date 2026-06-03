import SwiftUI

/// Component #8 — summary block for the top of the revenue report.
struct RevenueSummaryHeader: View {
    @Environment(\.theme) private var theme

    let summary: RevenueSummary
    let isLive: Bool

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                if !summary.byMethod.isEmpty {
                    Divider().overlay(theme.border)
                    breakdown
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Выручка")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)

            AmountText(amount: summary.total, size: 30)

            HStack(spacing: Spacing.sm) {
                Text("\(summary.count) поступлений")
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()

                if summary.cryptoConvertedRub > 0 {
                    cryptoChip
                }
            }
        }
    }

    private var cryptoChip: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text("Крипта → ₽: \(CryptoFormat.compactRub(summary.cryptoConvertedRub))")
                .font(BrandFont.micro.weight(.medium))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(theme.surface, in: Capsule())
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
    }

    private var breakdown: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(summary.byMethod) { slice in
                methodRow(slice)
            }
        }
    }

    private func methodRow(_ slice: RevenueSummary.MethodSlice) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text(slice.method.title)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: Spacing.sm)
                Text(CryptoFormat.rub(slice.amount))
                    .font(BrandFont.caption.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
            }
            ProgressBar(
                value: summary.share(slice),
                tint: slice.method == .crypto ? nil : theme.accent,
                useCryptoGradient: slice.method == .crypto,
                height: 6
            )
        }
    }
}

#Preview {
    RevenueSummaryHeader_PreviewHost()
}

private struct RevenueSummaryHeader_PreviewHost: View {
    private var summary: RevenueSummary {
        RevenueSummary(
            total: 1_284_500,
            count: 42,
            cryptoConvertedRub: 318_400,
            byMethod: [
                .init(method: .card, amount: 620_000),
                .init(method: .sbp, amount: 246_100),
                .init(method: .digitalRuble, amount: 100_000),
                .init(method: .crypto, amount: 318_400)
            ]
        )
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            RevenueSummaryHeader(summary: summary, isLive: true)
            RevenueSummaryHeader(summary: .empty, isLive: false)
        }
        .padding(Spacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}
