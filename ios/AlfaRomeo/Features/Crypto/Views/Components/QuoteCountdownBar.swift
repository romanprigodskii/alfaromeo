import SwiftUI

/// TTL countdown for a live quote (§10.8 «re-quote с TTL при волатильности»). Pure presentation —
/// the parent drives `remaining` (e.g. from a `TimelineView`) and reacts to expiry. When the quote is
/// live it shows a shrinking cold-gradient bar + seconds; at zero it warns that the rate must refresh.
struct QuoteCountdownBar: View {
    let remaining: TimeInterval
    var total: TimeInterval = 20

    @Environment(\.theme) private var theme

    private var fraction: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }
    private var expired: Bool { remaining <= 0 }
    private var seconds: Int { Int(remaining.rounded(.up)) }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: expired ? "clock.arrow.circlepath" : "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(expired ? theme.warning : (theme.accentCrypto.first ?? theme.accent))

            if expired {
                Text("Курс обновился — подтвердите заново")
                    .font(BrandFont.caption.weight(.medium))
                    .foregroundStyle(theme.warning)
            } else {
                Text("Курс действует \(seconds) с")
                    .font(BrandFont.caption.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: Spacing.sm)

            ProgressBar(value: fraction, useCryptoGradient: !expired, height: 4)
                .frame(width: 64)
                .opacity(expired ? 0.3 : 1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(theme.elevated, in: Capsule())
        .animation(.easeInOut(duration: 0.3), value: expired)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        QuoteCountdownBar(remaining: 14)
        QuoteCountdownBar(remaining: 0)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
