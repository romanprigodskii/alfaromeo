import SwiftUI

/// «Команда и роли» — the business-mode team hub (§8.2, §9.9). The root of the **Команда** tab; it
/// registers every ``TeamRoute`` on the tab's own `NavigationStack` (the self-contained one-stack
/// pattern of the Crypto/Mobile hubs), so sub-screens push without touching the shell.
///
/// Surfaces, in priority order: the **«на подпись»** task block (2-of-N approvals waiting, §11.8), the
/// **«заплатить поставщику»** action (§8.3), the сотрудники roster with **роли/права**, and the
/// **корп-карты**.
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                if !store.didLoad {
                    loading
                } else {
                    header
                    approvalsBlock
                    paySupplierAction
                    teamBlock
                    corpCardsBlock
                }
            }
            .padding(.horizontal, Spacing.screen)
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

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.activeProfile?.displayName ?? "Бизнес")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("\(store.members.count) в команде, вторая подпись от \(MoneyFormat.compact(store.policy.thresholdRub))")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            if let me = store.currentMember { RoleBadge(role: me.role, compact: true) }
        }
    }

    // MARK: «На подпись» (§8.2 задачи / §11.8)

    private var approvalsBlock: some View {
        let pending = store.pendingApprovalItems
        return GroupedSection("На подпись",
                              actionTitle: pending.isEmpty ? nil : "Все",
                              action: { router.push(TeamRoute.approvals) }) {
            if pending.isEmpty {
                ListRow(icon: "checkmark.seal", title: "Нет платежей на подпись")
            } else {
                ForEach(pending.prefix(2)) { item in
                    Button { router.push(TeamRoute.approvalDetail(approvalId: item.id)) } label: {
                        ApprovalRow(item: item)
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    // MARK: Платёж поставщику (§8.3)

    private var paySupplierAction: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Заплатить поставщику") {
                router.push(TeamRoute.paySupplier)
            }
            Text("Крупный платёж требует второй подписи")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Сотрудники + роли

    private var teamBlock: some View {
        GroupedSection("Сотрудники", actionTitle: "Все", action: { router.push(TeamRoute.members) }) {
            ForEach(store.members.prefix(3)) { member in
                Button { router.push(TeamRoute.memberDetail(memberId: member.id)) } label: {
                    MemberRow(member: member)
                }
                .buttonStyle(.row)
            }
            Button { router.push(TeamRoute.roles) } label: {
                ListRow(icon: "checklist", title: "Роли и права",
                        subtitle: "Владелец, бухгалтер, менеджер", showsChevron: true)
            }
            .buttonStyle(.row)
            actionRow("Добавить сотрудника", icon: "person.badge.plus") { router.push(TeamRoute.addMember) }
        }
    }

    // MARK: Корп-карты

    private var corpCardsBlock: some View {
        GroupedSection("Корп-карты", actionTitle: "Все", action: { router.push(TeamRoute.corpCards) }) {
            ForEach(store.corpCards.prefix(2)) { card in
                Button { router.push(TeamRoute.corpCardDetail(cardId: card.id)) } label: {
                    CorpCardRow(card: card)
                }
                .buttonStyle(.row)
            }
            if store.corpCards.isEmpty {
                Text("Корп-карт пока нет")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            }
            actionRow("Выпустить корп-карту", icon: "creditcard") { router.push(TeamRoute.issueCard(memberId: nil)) }
        }
    }

    // MARK: Helpers

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm + 4) {
                GlyphCircle(systemImage: icon)
                Text(title).font(BrandFont.bodyM).foregroundStyle(theme.accent)
                Spacer()
            }
            .frame(minHeight: Spacing.rowMinHeight)
            .contentShape(Rectangle())
            .groupedRowTextInset(48)
        }
        .buttonStyle(.row)
    }

    private var loading: some View {
        GroupedSection {
            ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
        }
        .accessibilityLabel("Загружаем команду")
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
