import SwiftUI

/// «На подпись» (§8.2 задачи / §11.8): payments awaiting a 2-of-N signature, plus a closed history.
/// Each row → ``ApprovalDetailView`` to sign or reject.
struct ApprovalsListView: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared

    var body: some View {
        let pending = store.pendingApprovalItems
        let closed = store.allApprovalItems.filter { $0.request.status != .pending }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if pending.isEmpty && closed.isEmpty {
                    emptyState
                }
                if !pending.isEmpty {
                    group("Ожидают подписи", items: pending)
                }
                if !closed.isEmpty {
                    group("История", items: closed)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("На подпись")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, items: [ApprovalItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            ForEach(items) { item in
                Button { router.push(TeamRoute.approvalDetail(approvalId: item.id)) } label: {
                    ApprovalCard(item: item)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var emptyState: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 28))
                    .foregroundStyle(theme.isDark ? theme.success : BrandColors.successInkLight)
                Text("Нет платежей на подпись").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Крупный платёж поставщику появится здесь, когда инициатор поставит первую подпись (§8.3).")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
