import SwiftUI

/// Roles × rights (§8.2): for each role — its badge, blurb, and the full permission matrix with
/// allow/deny ticks. Tops with the multi-step signing policy (§11.8) so «кто и когда подписывает» is
/// explicit.
struct RolesMatrixView: View {
    @Environment(\.theme) private var theme
    @State private var store = TeamStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                signingPolicyCard
                ForEach(RoleCatalog.demoRoles, id: \.self) { role in
                    roleCard(role)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Роли и права")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var signingPolicyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Многоступенчатая подпись", systemImage: "signature")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Платежи свыше \(SupplierPaymentModel.rub(store.policy.thresholdRub)) требуют \(store.policy.requiredSigners)-of-N подпись. Подписывать могут только владелец и бухгалтер (§11.8).")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.sm) {
                    ForEach(store.eligibleSigners) { signer in
                        HStack(spacing: Spacing.xs) {
                            Avatar(initials: signer.initials, size: 24)
                            Text(signer.name.split(separator: " ").first.map(String.init) ?? signer.name)
                                .font(BrandFont.micro.weight(.medium)).foregroundStyle(theme.textPrimary)
                        }
                        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                        .background(theme.elevated, in: Capsule())
                    }
                }
            }
        }
    }

    private func roleCard(_ role: MembershipRole) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    RoleBadge(role: role)
                    Spacer()
                    let count = RoleCatalog.permissions(role).count
                    Text("\(count) из \(TeamPermission.allCases.count) прав")
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
                Text(RoleCatalog.blurb(role)).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(theme.border)
                PermissionList(granted: RoleCatalog.permissions(role))
            }
        }
    }
}
