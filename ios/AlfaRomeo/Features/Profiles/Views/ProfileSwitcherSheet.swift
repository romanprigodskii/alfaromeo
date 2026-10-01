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
                VStack(alignment: .leading, spacing: Spacing.section) {
                    accountHeader

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        profileList
                        if let error = model.error {
                            Text(error).font(BrandFont.footnote).foregroundStyle(theme.danger)
                                .padding(.horizontal, Spacing.md)
                        }
                    }

                    settingsSection(session: $session)

                    logoutButton
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
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

    private var accountHeader: some View {
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: Spacing.md) {
                Avatar(initials: session.avatarInitials, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.activeProfile?.displayName ?? session.activeProfile?.type.label ?? "Профиль")
                        .font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text("Профиль и настройки")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
            }
            .padding(.top, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Profile list

    private var profileList: some View {
        GroupedSection("Профили") {
            ForEach(session.profiles) { profile in
                profileRow(profile)
            }
            NavigationLink {
                AddProfileMenuView()
            } label: {
                ListRow(icon: "plus", title: "Добавить профиль", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isActive = profile.id == session.activeProfile?.id
        let badgeTier = session.currentTier(for: profile.id, fallback: model.tiers[profile.id] ?? .base)
        return Button {
            Task {
                if await model.switchTo(profile, session: session) { shell.dismiss() }
            }
        } label: {
            HStack(spacing: ListRow.glyphSpacing) {
                // The glyph carries the profile's context colour (§5.2 marker) on a neutral circle.
                GlyphCircle(systemImage: profile.type.icon, size: ListRow.glyphSize,
                            tint: profile.type.markerColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName ?? profile.type.label)
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(model.tiers[profile.id] != nil
                         ? "\(profile.type.label), \(badgeTier.shortLabel)"
                         : profile.type.label)
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                } else if model.switchingId == profile.id {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
            .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile.displayName ?? profile.type.label), \(profile.type.label)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isActive ? "Активный профиль" : "Переключить профиль")
    }

    // MARK: Settings + debug

    private func settingsSection(session: Bindable<AppSession>) -> some View {
        GroupedSection("Настройки") {
            SettingsToggleRow(icon: "faceid", title: "Face ID при входе в бизнес",
                              subtitle: "Повторная биометрия", isOn: session.requireBiometricForBusinessSwitch)
            NavigationLink {
                NetworkDebugView()
            } label: {
                ListRow(icon: "ladybug", title: "Сетевой слой",
                        subtitle: "Моки, live-тики, AI-стрим", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    // MARK: Logout

    private var logoutButton: some View {
        Button { session.signOut() } label: {
            Text("Выйти")
                .font(BrandFont.headline)
                .foregroundStyle(theme.danger)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
