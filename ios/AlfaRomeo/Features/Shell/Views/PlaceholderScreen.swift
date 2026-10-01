import SwiftUI

/// Generic themed placeholder for a section root or a pushed detail. Lists the section's future
/// sub-screens (§9) and can push a demo detail to exercise the section's Router/NavigationStack.
struct PlaceholderScreen: View {
    let title: String
    let blurb: String
    var items: [String] = []
    var showsScopedSummary = false
    var onPushDemo: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                if showsScopedSummary {
                    ScopedSummaryCard()
                    DashboardQuickActions()
                }

                Text(blurb)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)

                if !items.isEmpty {
                    GroupedSection {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            ListRow(icon: "circle.dashed", title: item, subtitle: "Скоро")
                        }
                    }
                }

                if let onPushDemo {
                    PrimaryButton(title: "Открыть демо-экран", action: onPushDemo)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        // Reserve room at the bottom so the floating AI-copilot button never occludes the last
        // row / primary CTA.
        .contentMargins(.bottom, 96, for: .scrollContent)
    }
}

#Preview {
    NavigationStack {
        PlaceholderScreen(
            title: "Главная",
            blurb: "Пример секции-заглушки.",
            items: ["Дашборд", "Карты", "Счета"],
            onPushDemo: {}
        )
        .navigationTitle("Главная")
    }
    .environment(\.theme, .default)
}
