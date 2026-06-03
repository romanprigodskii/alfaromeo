import SwiftUI

/// A compact, profile-scoped snapshot shown on the dashboard. Reloads via ``APIClient`` whenever
/// the active profile changes — visible proof that data is scoped per `profileId` (§5.3).
struct ScopedSummaryCard: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var accounts: [Account] = []
    @State private var cards: [Card] = []
    @State private var baseTier: SubscriptionTier?

    private var totalRub: Double {
        accounts.filter { $0.currency == "RUB" }.reduce(0) { $0 + $1.balance }
    }

    /// Effective tier reflects a live in-session upgrade (§4).
    private var tier: SubscriptionTier? {
        guard let baseTier, let pid = session.activeProfile?.id else { return baseTier }
        return session.currentTier(for: pid, fallback: baseTier)
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Circle().fill(theme.accent).frame(width: 10, height: 10)
                    Text(session.activeProfile?.displayName ?? "Профиль")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    if let tier { Badge(kind: .text(tier.shortLabel), tint: theme.accent) }
                }

                AmountText(amount: totalRub, size: 28)

                HStack(spacing: Spacing.xl) {
                    stat("Счета", "\(accounts.count)")
                    stat("Карты", "\(cards.count)")
                    if let type = session.activeProfile?.type {
                        stat("Контекст", type.label)
                    }
                }

                Text("scoped · \(session.activeProfile?.id ?? "—")")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .task(id: session.activeProfile?.id) { await load() }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
    }

    private func load() async {
        guard let pid = session.activeProfile?.id else { return }
        // Clear first so the previous profile's figures never show under the new header.
        accounts = []; cards = []; baseTier = nil
        accounts = (try? await api.accounts(profileId: pid)) ?? []
        cards = (try? await api.cards(profileId: pid)) ?? []
        baseTier = (try? await api.subscription(profileId: pid))?.tier
    }
}
