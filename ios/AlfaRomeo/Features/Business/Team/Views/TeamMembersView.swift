import SwiftUI

/// Full team roster (§8.2). Members grouped visually by their role badge; tap → ``MemberDetailView``.
struct TeamMembersView: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 { Divider().overlay(theme.border) }
                            Button { router.push(TeamRoute.memberDetail(memberId: member.id)) } label: {
                                MemberRow(member: member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                PrimaryButton(title: "Добавить сотрудника", icon: "person.badge.plus") {
                    router.push(TeamRoute.addMember)
                }
                rolesLegend
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Команда")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rolesLegend: some View {
        Button { router.push(TeamRoute.roles) } label: {
            SurfaceCard(padding: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checklist").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Роли и права").font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        Text("Какие права у каждой роли").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
