import SwiftUI

/// «Команда и роли» — the business-mode team hub (§8.2, §9.9). The root of the **Команда** tab; it
/// registers every ``TeamRoute`` on the tab's own `NavigationStack` (the self-contained one-stack
/// pattern of the Crypto/Mobile hubs), so sub-screens push without touching the shell.
///
/// Surfaces, in priority order: the **«на подпись»** task block (2-of-N approvals waiting, §11.8), the
/// **«заплатить поставщику»** action (§8.3), the **роли/права** roster + matrix, and the **корп-карты**.
/// Runs in the graphite business theme resolved by the profile (§8/§13.1).
struct TeamHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = TeamStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var currentUserId: String { session.currentUser?.id ?? "u_demo" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !store.didLoad {
                    loading
                } else {
                    headerCard
                    approvalsBlock
                    paySupplierAction
                    teamBlock
                    rolesEntry
                    corpCardsBlock
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Команда")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: TeamRoute.self) { $0.destination }
        .task(id: profileId) {
            await store.load(api: api, profileId: profileId, currentUserId: currentUserId)
        }
    }

    // MARK: Header

    private var headerCard: some View {
        SurfaceCard {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(theme.accent.opacity(0.16)).frame(width: 48, height: 48)
                    Image(systemName: "person.2.fill").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.activeProfile?.displayName ?? "Бизнес")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("\(store.members.count) в команде · 2-of-N подпись от \(Int(store.policy.thresholdRub / 1000)) тыс ₽")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let me = store.currentMember { RoleBadge(role: me.role, compact: true) }
            }
        }
    }

    // MARK: «На подпись» (§8.2 задачи / §11.8)

    @ViewBuilder private var approvalsBlock: some View {
        let pending = store.pendingApprovalItems
        sectionHeader("На подпись",
                      badge: pending.isEmpty ? nil : pending.count,
                      actionTitle: pending.isEmpty ? nil : "Все") {
            router.push(TeamRoute.approvals)
        }
        if pending.isEmpty {
            SurfaceCard {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.isDark ? theme.success : BrandColors.successInkLight)
                    Text("Нет платежей, ожидающих подписи.")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                }
            }
        } else {
            VStack(spacing: Spacing.md) {
                ForEach(pending.prefix(2)) { item in
                    Button { router.push(TeamRoute.approvalDetail(approvalId: item.id)) } label: {
                        ApprovalCard(item: item)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: Платёж поставщику (§8.3)

    private var paySupplierAction: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Заплатить поставщику", icon: "paperplane.fill") {
                router.push(TeamRoute.paySupplier)
            }
            Text("Крупный платёж уходит на 2-of-N подпись (§8.3)")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Команда

    private var teamBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Команда", actionTitle: "Все") { router.push(TeamRoute.members) }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(store.members.prefix(3).enumerated()), id: \.element.id) { index, member in
                        if index > 0 { Divider().overlay(theme.border) }
                        Button { router.push(TeamRoute.memberDetail(memberId: member.id)) } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().overlay(theme.border)
                    Button { router.push(TeamRoute.addMember) } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accent)
                                .frame(width: 40, height: 40)
                                .background(theme.accent.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            Text("Добавить сотрудника")
                                .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.accent)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rolesEntry: some View {
        Button { router.push(TeamRoute.roles) } label: {
            SurfaceCard(padding: Spacing.md) {
                ListRow(icon: "checklist", title: "Роли и права",
                        subtitle: "Кто что может: владелец · бухгалтер · менеджер",
                        showsChevron: true)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Корп-карты

    private var corpCardsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Корп-карты", actionTitle: "Все") { router.push(TeamRoute.corpCards) }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(store.corpCards.prefix(2).enumerated()), id: \.element.id) { index, card in
                        if index > 0 { Divider().overlay(theme.border) }
                        Button { router.push(TeamRoute.corpCardDetail(cardId: card.id)) } label: {
                            CorpCardRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                    if store.corpCards.isEmpty {
                        Text("Ещё нет корп-карт. Выпустите карту сотруднику с лимитом.")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.sm)
                    }
                    Divider().overlay(theme.border)
                    Button { router.push(TeamRoute.issueCard(memberId: nil)) } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "creditcard.and.123")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accent)
                                .frame(width: 40, height: 40)
                                .background(theme.accent.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            Text("Выпустить корп-карту")
                                .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.accent)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Helpers

    private var loading: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().tint(theme.accent)
            Text("Загружаем команду…").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func sectionHeader(_ title: String, badge: Int? = nil,
                               actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                if let badge { Badge(kind: .count(badge), tint: theme.accent) }
            }
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(BrandFont.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

private struct TeamHubPreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack { TeamHubView() }
            .themeProvider(profileType: .business)
            .environment(session)
            .environment(Router())
            .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Команда · бизнес") { TeamHubPreviewHost() }
