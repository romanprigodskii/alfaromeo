import SwiftUI

/// Quick-prompt chips for the AI-бухгалтер (§8.2). Tapping a chip sends the prompt to live Claude.
/// Informational chips fetch insights; the two agentic chips (счёт / оплата) make Claude propose a
/// `create_invoice` / `pay_supplier` draft — which the user then confirms with biometrics.
struct AccountantQuickPromptBar: View {
    var onPrompt: (String) -> Void

    @Environment(\.theme) private var theme

    private struct Prompt: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let text: String
        let agentic: Bool
    }

    private let prompts: [Prompt] = [
        .init(title: "Кассовый разрыв", icon: "exclamationmark.triangle", text: "Когда возможен кассовый разрыв и на какую сумму? Как его закрыть?", agentic: false),
        .init(title: "Прогноз 90 дней", icon: "chart.xyaxis.line", text: "Покажи прогноз денежного потока на 90 дней.", agentic: false),
        .init(title: "Оптимизация налога", icon: "percent", text: "Как снизить налоговую нагрузку? Стоит ли менять режим налогообложения?", agentic: false),
        .init(title: "Анализ расходов", icon: "chart.pie", text: "Разбери мои расходы по категориям и предложи, где сэкономить.", agentic: false),
        .init(title: "Выставить счёт", icon: "doc.text", text: "Выставь счёт на 120 000 ₽ для ООО «Ромашка».", agentic: true),
        .init(title: "Оплатить поставщику", icon: "arrow.up.right", text: "Оплати поставщику «Поставки-Юг» 85 000 ₽.", agentic: true),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(prompts) { p in
                    Button { onPrompt(p.text) } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: p.icon)
                                .font(.system(size: 13, weight: .regular))
                            Text(p.title).font(BrandFont.body(15, weight: .medium))
                        }
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, Spacing.sm + 4)
                        .frame(height: 36)
                        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip + 2, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }
}
