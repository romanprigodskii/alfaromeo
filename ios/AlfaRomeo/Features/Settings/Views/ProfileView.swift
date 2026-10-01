import SwiftUI

/// Профиль (§9.8): имя + тариф, «Близкие», документы (Паспорт/ИНН), контакты (телефон/email),
/// and the entry into Настройки. Pushed from the profile switcher (§5.2); the switcher itself stays
/// the place to change profiles. Profile-scoped; the tier reflects the active profile's tier.
struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var tier: SubscriptionTier?

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var identity: ProfileIdentity { .demo(displayName: session.activeProfile?.displayName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                closePeople
                documents
                contacts
                settingsLink
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
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
            Avatar(initials: session.avatarInitials, size: 72)
            Text(identity.fullName)
                .font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(tier?.displayName ?? " ")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Близкие

    private var closePeople: some View {
        GroupedSection("Близкие") {
            ForEach(CloseContact.demo) { person in
                HStack(spacing: ListRow.glyphSpacing) {
                    Avatar(initials: person.initials, size: ListRow.glyphSize)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Text(person.relation).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: Spacing.rowMinHeightTwoLine)
                .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Документы

    private var documents: some View {
        GroupedSection("Документы") {
            ListRow(icon: "person.text.rectangle", title: "Паспорт РФ",
                    subtitle: "Подтверждён", value: identity.passportMasked)
            ListRow(icon: "number", title: "ИНН", value: identity.innMasked)
        }
    }

    // MARK: Контакты

    private var contacts: some View {
        GroupedSection("Контакты") {
            ListRow(icon: "phone", title: "Телефон",
                    value: session.currentUser?.phone ?? "Не указан")
            ListRow(icon: "envelope", title: "Email", value: identity.email)
        }
    }

    // MARK: Настройки entry

    private var settingsLink: some View {
        GroupedSection {
            NavigationLink { SettingsView() } label: {
                ListRow(icon: "gearshape", title: "Настройки",
                        subtitle: "Безопасность, уведомления, тема", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
