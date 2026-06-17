import SwiftUI

/// Profile switcher (§5.2): list of the user's profiles with type icon, tier badge and context
/// color marker; switch in one tap (optional biometric gate for business); "+ Добавить профиль";
/// a business-biometric setting; plus the debug harness and logout.
struct ProfileSwitcherSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(ShellState.self) private var shell
    @Environment(\.theme) private var theme

    @State private var model = ProfileSwitcherModel()
    @State private var detent: PresentationDetent = .large

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    accountCard

                    Text("Сменить профиль")
                        .font(BrandFont.title)
                        .foregroundStyle(theme.textPrimary)

                    profileList
                    addProfileLink

                    if let error = model.error {
                        Text(error).font(BrandFont.caption).foregroundStyle(theme.danger)
                    }

                    settingsCard(session: $session)

                    Divider().overlay(theme.border)

                    debugLink
                    logoutButton

                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background)
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
        .task { await model.loadTiers(api: api, profiles: session.profiles) }
    }

    // MARK: Account (Профиль и настройки, §9.8)

    private var accountCard: some View {
        NavigationLink {
            ProfileView()
        } label: {
            SurfaceCard(padding: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Avatar(initials: session.avatarInitials, size: 44, ringColor: theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.activeProfile?.displayName ?? session.activeProfile?.type.label ?? "Профиль")
                            .font(BrandFont.bodyM.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Text("Профиль и настройки")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Profile list

    private var profileList: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                ForEach(Array(session.profiles.enumerated()), id: \.element.id) { index, profile in
                    profileRow(profile)
                    if index < session.profiles.count - 1 {
                        Divider().overlay(theme.border)
                    }
                }
            }
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isActive = profile.id == session.activeProfile?.id
        let marker = profile.type.markerColor
        let badgeTier = session.currentTier(for: profile.id, fallback: model.tiers[profile.id] ?? .base)
        return Button {
            Task {
                if await model.switchTo(profile, session: session) { shell.dismiss() }
            }
        } label: {
            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(marker).frame(width: 4, height: 38)
                Image(systemName: profile.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(marker)
                    .frame(width: 36, height: 36)
                    .background(marker.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName ?? profile.type.label)
                        .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text(profile.type.label)
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                if model.tiers[profile.id] != nil {
                    Badge(kind: .text(badgeTier.shortLabel), tint: marker)
                }
                if isActive {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
                } else if model.switchingId == profile.id {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(minHeight: 44)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile.displayName ?? profile.type.label), \(profile.type.label)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isActive ? "Активный профиль" : "Переключить профиль")
    }

    private var addProfileLink: some View {
        NavigationLink {
            AddProfileMenuView()
        } label: {
            SurfaceCard(padding: Spacing.sm) {
                ListRow(icon: "plus", title: "Добавить профиль",
                        subtitle: "Личный · Бизнес", showsChevron: true)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings

    private func settingsCard(session: Bindable<AppSession>) -> some View {
        SurfaceCard(padding: Spacing.md) {
            Toggle(isOn: session.requireBiometricForBusinessSwitch) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID при входе в бизнес").font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                    Text("Повторный биометрический unlock (§5.2).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
        }
    }

    // MARK: Debug + logout

    private var debugLink: some View {
        NavigationLink {
            NetworkDebugView()
        } label: {
            SurfaceCard(padding: Spacing.sm) {
                ListRow(icon: "ladybug.fill", title: "Сетевой слой · debug",
                        subtitle: "Моки, live-тики, AI-стрим", showsChevron: true)
            }
        }
        .buttonStyle(.plain)
    }

    private var logoutButton: some View {
        Button { session.signOut() } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти")
            }
            .font(BrandFont.headline)
            .foregroundStyle(theme.danger)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(theme.danger.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
