import SwiftUI

/// Onboarding empty state for a profile with no money objects (§10.2 «пустой профиль»). Offers the
/// two first products, a card and a crypto wallet (§6.2, §9.6), as rows in one grouped list.
struct HomeEmptyState: View {
    var onOpenCard: () -> Void
    var onOpenWallet: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Добро пожаловать").font(BrandFont.title1).foregroundStyle(theme.textPrimary)
                Text("Откройте первый продукт.")
                    .font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            }

            GroupedSection {
                Button(action: onOpenCard) {
                    ListRow(icon: "creditcard", title: "Заказать карту",
                            subtitle: "Виртуальная сразу появится в Apple Pay", showsChevron: true)
                }
                .buttonStyle(.row)

                Button(action: onOpenWallet) {
                    ListRow(icon: "bitcoinsign", title: "Создать крипто-кошелёк",
                            subtitle: "₽, цифровой ₽ и крипта в одном кошельке", showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }
}
