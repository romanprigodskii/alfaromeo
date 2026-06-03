import SwiftUI

/// Hero card for the total ₽ balance across every business account — ₽ settlement + multicurrency +
/// crypto treasury, all valued at the **live** rate (§8.2). Shared by the Счета header (read-only) and
/// the Дашборд «баланс по счетам» card (tappable → Счета tab). The «live-курс / оффлайн-курс» pill
/// reflects ``LivePriceService``, so a stale/offline price book is never silently presented as live.
struct AccountBalanceHero: View {
    let totalRub: Double
    let isLive: Bool
    let subline: String
    /// When set, the card becomes a button with a trailing CTA (used on the dashboard to open Счета).
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        if let action {
            Button(action: action) { card }
                .buttonStyle(PressableButtonStyle())
        } else {
            card
        }
    }

    private var card: some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top) {
                    Text("БАЛАНС · ВСЕ СЧЕТА")
                        .font(BrandFont.micro.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: Spacing.sm)
                    livePill
                }

                AmountText(amount: totalRub, size: 34)

                Text(subline)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle {
                    Divider().overlay(theme.border)
                    HStack(spacing: Spacing.xxs) {
                        Text(actionTitle).font(BrandFont.caption.weight(.medium))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accent)
                }
            }
        }
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text(isLive ? "live-курс" : "оффлайн-курс")
                .font(BrandFont.micro.weight(.medium))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background((isLive ? theme.success : theme.warning).opacity(0.12), in: Capsule(style: .continuous))
    }
}
