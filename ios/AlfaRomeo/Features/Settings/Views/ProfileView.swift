import SwiftUI

/// Профиль (§9.8): имя + тир-бейдж, «Близкие», Мои документы (Паспорт/ИНН), «Обо мне» (телефон/email),
/// and the entry into Настройки. Pushed from the profile switcher (§5.2) — the switcher itself stays
/// the place to change profiles. Profile-scoped; the tier badge reflects the active profile's tier.
struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var tier: SubscriptionTier?

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var identity: ProfileIdentity { .demo(displayName: session.activeProfile?.displayName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                closePeople
                documents
                about
                settingsLink
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileId) {
            let sub = try? await api.subscription(profileId: profileId)
            tier = session.currentTier(for: profileId, fallback: sub?.tier ?? .base)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Avatar(initials: session.avatarInitials, size: 72, ringColor: theme.accent)
            Text(identity.fullName)
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            if let tier {
                Badge(kind: .text(tier.displayName), tint: theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: Близкие

    private var closePeople: some View {
        section("Близкие") {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(CloseContact.demo.enumerated()), id: \.element.id) { index, person in
                        HStack(spacing: Spacing.md) {
                            Avatar(initials: person.initials, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                                Text(person.relation).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, Spacing.sm)
                        if index < CloseContact.demo.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    // MARK: Документы

    private var documents: some View {
        section("Мои документы") {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ListRow(icon: "person.text.rectangle", title: "Паспорт РФ",
                            subtitle: "Подтверждён (KYC)", value: identity.passportMasked)
                    Divider().overlay(theme.border)
                    ListRow(icon: "number.square", title: "ИНН", subtitle: "Налоговый номер",
                            value: identity.innMasked)
                }
            }
        }
    }

    // MARK: Обо мне

    private var about: some View {
        section("Обо мне") {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ListRow(icon: "phone.fill", title: "Телефон",
                            value: session.currentUser?.phone ?? "—")
                    Divider().overlay(theme.border)
                    ListRow(icon: "envelope.fill", title: "Email", value: identity.email)
                }
            }
        }
    }

    // MARK: Настройки entry

    private var settingsLink: some View {
        NavigationLink { SettingsView() } label: {
            SurfaceCard(padding: Spacing.sm) {
                ListRow(icon: "gearshape.fill", title: "Настройки",
                        subtitle: "Безопасность · уведомления · тема · язык", showsChevron: true)
            }
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(BrandFont.micro).tracking(1.5).foregroundStyle(theme.textSecondary)
            content()
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
