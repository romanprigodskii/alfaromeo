import SwiftUI

/// Member card (§8.2): role, the full permission matrix for that role, the member's corp-cards, and
/// mock role-change / remove. The current user (owner) cannot be demoted or removed.
struct MemberDetailView: View {
    let memberId: String

    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared
    @State private var showRoleSheet = false

    private var member: TeamMember? { store.member(id: memberId) }

    var body: some View {
        ScrollView {
            if let member {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    profileCard(member)
                    permissionsCard(member)
                    cardsCard(member)
                    if !member.isCurrentUser { manageCard(member) }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Сотрудник не найден").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.screen)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle(member?.name ?? "Сотрудник")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Сменить роль", isPresented: $showRoleSheet, titleVisibility: .visible) {
            ForEach(RoleCatalog.demoRoles, id: \.self) { role in
                Button(RoleCatalog.label(role)) { store.changeRole(role, memberId: memberId) }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func profileCard(_ member: TeamMember) -> some View {
        SurfaceCard {
            HStack(spacing: Spacing.md) {
                Avatar(initials: member.initials, size: 56,
                       ringColor: member.isCurrentUser ? theme.accent : nil)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(member.name).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    Text(member.email).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    RoleBadge(role: member.role)
                }
                Spacer()
            }
        }
    }

    private func permissionsCard(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Права").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                if member.canSign {
                    Label("Может подписывать", systemImage: "signature")
                        .font(BrandFont.micro.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            SurfaceCard(padding: Spacing.sm) {
                PermissionList(granted: member.permissions)
            }
            Text(RoleCatalog.blurb(member.role))
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cardsCard(_ member: TeamMember) -> some View {
        let cards = store.cards(forMemberId: member.id)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Корп-карты").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                Button { router.push(TeamRoute.issueCard(memberId: member.id)) } label: {
                    Text("Выпустить").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
            SurfaceCard(padding: Spacing.sm) {
                if cards.isEmpty {
                    Text("Нет карт у сотрудника.").font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            if index > 0 { Divider().overlay(theme.border) }
                            Button { router.push(TeamRoute.corpCardDetail(cardId: card.id)) } label: {
                                CorpCardRow(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func manageCard(_ member: TeamMember) -> some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Сменить роль", icon: "arrow.triangle.2.circlepath") {
                showRoleSheet = true
            }
            Button {
                store.removeMember(memberId: member.id)
                router.pop()
            } label: {
                Text("Удалить из команды")
                    .font(BrandFont.callout.weight(.medium))
                    .foregroundStyle(theme.isDark ? theme.danger : BrandColors.dangerInkLight)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }
}
