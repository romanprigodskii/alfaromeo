import SwiftUI

/// Honest price-source chip (§11.4): «LIVE · Binance» / «LIVE · сервер» with a pulsing dot while a real
/// feed streams, «Binance · задержка» in amber when it goes quiet, «Демо-цены» in amber on the local
/// walk. Two looks: `.onGradient` (translucent white, for the crypto hero) and `.surface` (tinted
/// capsule on light cards, StatusPill-style ink colours for AA contrast).
struct PriceSourceBadge: View {
    enum Style { case onGradient, surface }

    let source: PriceSource
    var isStale: Bool = false
    var style: Style = .surface

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var healthy: Bool { source.isLive && !isStale }
    private var title: String { isStale ? source.staleTitle : source.badgeTitle }

    /// Status tint for the `.surface` look — darker ink in the light scheme (readable on the pale capsule).
    private var tint: Color {
        if healthy { return theme.isDark ? theme.success : BrandColors.successInkLight }
        return theme.isDark ? theme.warning : BrandColors.warningInkLight
    }

    private var foreground: Color { style == .onGradient ? .white : tint }
    private var dot: Color {
        switch style {
        case .onGradient: return healthy ? .white : BrandColors.warningDark
        case .surface:    return healthy ? theme.success : theme.warning
        }
    }
    private var capsule: Color { style == .onGradient ? .white.opacity(0.18) : tint.opacity(0.12) }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
                .opacity(healthy && pulse && !reduceMotion ? 0.35 : 1)
                .animation(healthy && !reduceMotion ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil,
                           value: pulse)
            Text(title)
                .font(BrandFont.micro.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(capsule, in: Capsule())
        .onAppear { pulse = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isStale ? "\(source.accessibilityLabel), обновление задерживается" : source.accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HStack {
            PriceSourceBadge(source: .exchange(.binance), style: .onGradient)
            PriceSourceBadge(source: .exchange(.binance), isStale: true, style: .onGradient)
            PriceSourceBadge(source: .demo, style: .onGradient)
        }
        .padding()
        .background(Theme.default.cryptoGradient)
        PriceSourceBadge(source: .backend)
        PriceSourceBadge(source: .exchange(.bybit))
        PriceSourceBadge(source: .exchange(.binance), isStale: true)
        PriceSourceBadge(source: .demo)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
