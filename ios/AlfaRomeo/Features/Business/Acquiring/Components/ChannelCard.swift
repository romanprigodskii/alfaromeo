import SwiftUI

/// One acceptance channel as a ``GroupedSection`` row in the acquiring hub: glyph, title, the methods
/// it covers, and (for crypto) the live USDT→₽ rate.
struct ChannelCard: View {
    let channel: AcquiringChannel
    let liveRate: Double?
    let isLive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var showsRate: Bool {
        channel == .crypto && liveRate != nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm + 4) {
                GlyphCircle(systemImage: channel.systemImage)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.title)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                    Text(channel.methods.joined(separator: ", "))
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                    if showsRate, let rate = liveRate {
                        rateLine(rate)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
            .groupedRowTextInset(48)
        }
        .buttonStyle(.row)
    }

    private func rateLine(_ rate: Double) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text("1 USDT = \(MoneyFormat.fiat(rate.rounded())), live-курс")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .padding(.top, 2)
    }
}

private struct ChannelCard_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(AcquiringChannel.allCases) { channel in
                ChannelCard(
                    channel: channel,
                    liveRate: channel == .crypto ? 101.42 : nil,
                    isLive: channel == .crypto,
                    action: {}
                )
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}

#Preview {
    ChannelCard_PreviewHost()
}
