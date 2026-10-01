import SwiftUI

/// The "+ Добавить профиль" entry points (§5.2): another personal, business onboarding, family,
/// or child; each pushes its own stub flow.
struct AddProfileMenuView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            GroupedSection(footer: "Все профили открываются по одному паспорту.") {
                ForEach(AddProfileKind.demoMenuKinds) { kind in
                    NavigationLink {
                        AddProfileStubView(kind: kind)
                    } label: {
                        ListRow(icon: kind.profileType.icon, title: kind.title,
                                subtitle: kind.menuSubtitle, showsChevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новый профиль")
        .navigationBarTitleDisplayMode(.inline)
    }
}
