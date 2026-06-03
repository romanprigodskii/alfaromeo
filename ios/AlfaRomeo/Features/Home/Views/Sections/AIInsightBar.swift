import SwiftUI

/// Top AI-insight line (§9.1, §10.2). Contextual but **static text this phase** — real Claude lands
/// in Phase 3 (§11.7). Tapping opens AI search (§9.1).
struct AIInsightBar: View {
    let dashboard: HomeDashboard
    let live: [String: Double]
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    /// Derived from the active profile context — deterministic, not a model call yet.
    private var message: String {
        switch dashboard.profileType {
        case .child:
            return "Карманные расходы под контролем — помогу спланировать накопления."
        case .business:
            return "Кэшфлоу стабилен. Спросите про кассовый разрыв или выставите счёт."
        case .personal, .joint:
            if !dashboard.wallets.isEmpty {
                return "Счета и портфель в плюсе. Спросите, как поднять кэшбек в июне."
            }
            return "Я ваш финансовый второй пилот — спросите что угодно о деньгах."
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.cryptoGradient)
                Text(message)
                    .font(BrandFont.callout)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(theme.cryptoGradient, lineWidth: 1).opacity(0.5)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("AI-инсайт. \(message)")
    }
}
