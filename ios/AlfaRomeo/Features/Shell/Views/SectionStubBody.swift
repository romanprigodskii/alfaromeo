import SwiftUI

/// Shared body for a Phase-1 section **root stub**: a short blurb plus an optional card of tappable
/// "rails" that push real routes — so a section's `.navigationDestination` is demonstrably wired
/// before the owning module fills in content. The owning module (1.1 / 1.3 / 1.4) replaces its
/// root's body entirely; this helper just keeps the rails identical and light meanwhile.
struct SectionStubBody: View {
    /// One tappable entry that pushes a route onto the section ``Router``.
    struct Rail {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    let blurb: String
    var rails: [Rail] = []

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(blurb)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)

                if !rails.isEmpty {
                    SurfaceCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            ForEach(Array(rails.enumerated()), id: \.offset) { index, rail in
                                Button(action: rail.action) {
                                    ListRow(icon: rail.icon, title: rail.title,
                                            subtitle: rail.subtitle, showsChevron: true)
                                }
                                .buttonStyle(.plain)
                                if index < rails.count - 1 {
                                    Divider().overlay(theme.border)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        // Reserve room so the floating AI-copilot button never occludes the last rail.
        .contentMargins(.bottom, 96, for: .scrollContent)
    }
}

#Preview {
    SectionStubBody(
        blurb: "Раздел-заглушка фазы 1.",
        rails: [
            .init(icon: "creditcard", title: "Карты профиля", subtitle: "§6.3") {},
            .init(icon: "magnifyingglass", title: "Поиск (AI)", subtitle: "§9.1") {},
        ]
    )
    .environment(\.theme, .default)
}
