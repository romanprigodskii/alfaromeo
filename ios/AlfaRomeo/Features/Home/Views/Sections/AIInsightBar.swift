import SwiftUI

/// AI-подсказка под балансом (§9.1, §10.2, DESIGN §7): одна строка текста и ссылка «Спросить».
/// Без иконок-искр и рамок. Текст детерминирован по контексту профиля; нажатие открывает копилот.
struct AIInsightBar: View {
    let dashboard: HomeDashboard
    let live: [String: Double]
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    /// Derived from the active profile context, deterministic (not a model call).
    private var message: String {
        switch dashboard.profileType {
        case .child:
            return "Карманные расходы под контролем. Помогу спланировать накопления."
        case .business:
            return "Кэшфлоу стабилен. Можно спросить про кассовый разрыв или выставить счёт."
        case .personal, .joint:
            if !dashboard.wallets.isEmpty {
                return "Счета и портфель в плюсе. Как поднять кэшбек в июне?"
            }
            return "Отвечу на вопросы о деньгах: расходы, переводы, кэшбек."
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(message)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Спросить")
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Подсказка ассистента. \(message)")
        .accessibilityHint("Открыть чат с ассистентом")
        .accessibilityAddTraits(.isButton)
    }
}
