import SwiftUI

/// The "+ Добавить профиль" entry points (§5.2): another personal, business onboarding, family,
/// or child — each pushes its own stub flow.
struct AddProfileMenuView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Один паспорт (KYC) — сколько угодно профилей. Выберите тип.")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        let kinds = AddProfileKind.demoMenuKinds
                        ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                            NavigationLink {
                                AddProfileStubView(kind: kind)
                            } label: {
                                ListRow(icon: kind.profileType.icon, title: kind.title,
                                        subtitle: kind.menuSubtitle, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            if index < kinds.count - 1 {
                                Divider().overlay(theme.border)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Добавить профиль")
        .navigationBarTitleDisplayMode(.inline)
    }
}
