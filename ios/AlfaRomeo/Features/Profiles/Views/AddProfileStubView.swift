import SwiftUI

/// The four "+ Добавить профиль" entry points (§5.1/§5.2).
enum AddProfileKind: String, CaseIterable, Identifiable {
    case personal, business, family, child

    var id: String { rawValue }

    /// Entry points shown in the "+ Добавить профиль" menu under the demo. Family/child are hidden
    /// (no real onboarding flow yet); their stub screens stay reachable in code for later phases
    /// (§5.1). Product decision, not a bug.
    static var demoMenuKinds: [AddProfileKind] { [.personal, .business] }

    var profileType: ProfileType {
        switch self {
        case .personal: return .personal
        case .business: return .business
        case .family:   return .joint
        case .child:    return .child
        }
    }

    var title: String {
        switch self {
        case .personal: return "Ещё один личный"
        case .business: return "Бизнес"
        case .family:   return "Семейный"
        case .child:    return "Детский"
        }
    }

    var menuSubtitle: String {
        switch self {
        case .personal: return "Второй личный профиль"
        case .business: return "ИП, ООО или самозанятый"
        case .family:   return "Общий бюджет с близкими"
        case .child:    return "Родительский контроль, детская карта"
        }
    }

    var newName: String {
        switch self {
        case .personal: return "Личный 2"
        case .business: return "Новый бизнес"
        case .family:   return "Семейный"
        case .child:    return "Детский"
        }
    }

    var ctaTitle: String {
        switch self {
        case .business: return "Создать бизнес-профиль"
        default:        return "Создать профиль"
        }
    }

    var blurb: String {
        switch self {
        case .personal: return "Второй личный профиль по тому же паспорту: отдельные счета, карты и лимиты."
        case .business: return "Приложение создаст бизнес-профиль и переключится в бизнес-режим."
        case .family:   return "Совместный профиль для семьи."
        case .child:    return "Детский профиль с родительским контролем."
        }
    }

    var bullets: [String] {
        switch self {
        case .personal: return ["Отдельные счета и карты", "Свои лимиты и тариф", "Один паспорт на все профили"]
        case .business: return ["ОГРН/ИНН и роли учредителей", "РКО, эквайринг, зарплаты", "Графитовая тема и свой таб-бар"]
        case .family:   return ["Общий счёт и цели", "Доступ для близких", "Совместные бюджеты"]
        case .child:    return ["Привязан к родителю", "Лимиты, категории, геозоны", "Детская карта"]
        }
    }
}

/// Stub screen for an add-profile entry point. The CTA creates a demo profile of this type and
/// switches to it (closing the switcher), so the shell re-themes / swaps the tab bar.
struct AddProfileStubView: View {
    let kind: AddProfileKind

    @Environment(AppSession.self) private var session
    @Environment(ShellState.self) private var shell
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                HStack(spacing: Spacing.md) {
                    GlyphCircle(systemImage: kind.profileType.icon, size: 56,
                                tint: kind.profileType.markerColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                        Text(kind.menuSubtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    }
                }

                GroupedSection(footer: kind.blurb) {
                    ForEach(kind.bullets, id: \.self) { bullet in
                        ListRow(title: bullet)
                    }
                }

                VStack(spacing: Spacing.sm) {
                    PrimaryButton(title: kind.ctaTitle) { create() }
                    Text("Демо: полный сценарий открытия появится позже.")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func create() {
        let id = "p_\(kind.rawValue)_\(session.profiles.count)"
        let profile = Profile(
            id: id,
            userId: session.currentUser?.id ?? MockData.userId,
            type: kind.profileType,
            displayName: kind.newName,
            theme: nil,
            createdAt: "2035-06-02T00:00:00Z"
        )
        session.addProfile(profile)
        shell.dismiss()
    }
}
