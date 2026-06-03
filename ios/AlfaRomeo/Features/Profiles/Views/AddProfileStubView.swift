import SwiftUI

/// The four "+ Добавить профиль" entry points (§5.1/§5.2).
enum AddProfileKind: String, CaseIterable, Identifiable {
    case personal, business, family, child

    var id: String { rawValue }

    /// Entry points shown in the "+ Добавить профиль" menu under the demo. Family/child are hidden
    /// (no real onboarding flow yet) — their stub screens stay reachable in code for later phases
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
        case .business: return "ИП / ООО / самозанятый — Ромео-Бизнес (§8)"
        case .family:   return "Общий бюджет с «Близкими»"
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
        case .business: return "Открыть бизнес-онбординг (демо)"
        default:        return "Создать профиль (демо)"
        }
    }

    var blurb: String {
        switch self {
        case .personal: return "Второй личный профиль под тем же паспортом — отдельные счета, карты и лимиты."
        case .business: return "Бизнес-онбординг (§8) — заглушка. Демо создаст бизнес-профиль и переключит режим."
        case .family:   return "Семейный/совместный профиль (§5.1) — заглушка точки входа."
        case .child:    return "Детский профиль с родительским контролем (§5.1) — заглушка точки входа."
        }
    }

    var bullets: [String] {
        switch self {
        case .personal: return ["Отдельные счета и карты", "Свои лимиты и тир", "Общий KYC"]
        case .business: return ["ОГРН/ИНН и роли учредителей", "РКО · эквайринг · зарплаты", "Графитовая тема и свой таб-бар"]
        case .family:   return ["Общий счёт и цели", "Доступ для «Близких»", "Совместные бюджеты"]
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: kind.profileType.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(kind.profileType.markerColor)
                        .frame(width: 56, height: 56)
                        .background(kind.profileType.markerColor.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                        Text(kind.menuSubtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }

                Text(kind.blurb).font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(kind.bullets.enumerated()), id: \.offset) { index, bullet in
                            ListRow(icon: "checkmark", title: bullet)
                            if index < kind.bullets.count - 1 {
                                Divider().overlay(theme.border)
                            }
                        }
                    }
                }

                PrimaryButton(title: kind.ctaTitle, icon: "arrow.right") { create() }

                Text("Полноценный флоу — в соответствующей фазе. Сейчас это заглушка точки входа.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.lg)
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
