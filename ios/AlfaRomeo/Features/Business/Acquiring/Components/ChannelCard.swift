import SwiftUI

/// Component #1 — a tappable acceptance-channel card for the acquiring hub.
struct ChannelCard: View {
    let channel: AcquiringChannel
    let liveRate: Double?
    let isLive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var iconTint: Color {
        channel == .crypto ? (theme.accentCrypto.first ?? theme.accent) : theme.accent
    }

    private var showsRate: Bool {
        channel == .crypto && liveRate != nil
    }

    var body: some View {
        Button(action: action) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    header
                    methodChips
                    if showsRate, let rate = liveRate {
                        rateLine(rate)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: channel.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 40, height: 40)
                .background(
                    iconTint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(BrandFont.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(channel.subtitle)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: Spacing.xs)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var methodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(channel.methods, id: \.self) { method in
                    Text(method)
                        .font(BrandFont.micro)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(theme.elevated, in: Capsule(style: .continuous))
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func rateLine(_ rate: Double) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text("1 USDT = \(CryptoFormat.rub(rate)) · live")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
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
