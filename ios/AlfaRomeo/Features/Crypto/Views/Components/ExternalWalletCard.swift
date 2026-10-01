import SwiftUI

/// Provider row for the link screen (§9.6 🆕): MetaMask / Trust / Ledger / TON. Tap to start a
/// watch-only link. A grouped-list row (docs/DESIGN.md §4: no tile grids).
struct ExternalWalletProviderTile: View {
    let provider: ExternalWalletProvider
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            ListRow(icon: provider.icon, title: provider.label, subtitle: provider.tagline, showsChevron: true)
        }
        .buttonStyle(.row)
    }
}

/// A linked watch-only wallet row (§9.6): provider glyph, masked address (mono), ₽ value, read-only tag.
/// When `onUnlink` is supplied, a trailing menu offers «Отвязать» — removing the watch-only link so the
/// unified portfolio recomputes (``CryptoStore/unlinkExternalWallet(id:)``).
struct ExternalWalletRow: View {
    let wallet: ExternalWallet
    let valueRub: Double
    /// Display currency for the ₽ value (§9.6 ₽/$ toggle).
    var denomination: PortfolioDenomination = .rub
    var usdRub: Double = 1
    var onUnlink: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @State private var confirmUnlink = false

    var body: some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: wallet.provider.icon, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.label).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary).lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(wallet.shortAddress).font(BrandFont.code(13)).foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    WatchOnlyTag()
                }
            }
            Spacer(minLength: Spacing.sm)
            Text(CryptoFormat.money(valueRub, denom: denomination, usdRub: usdRub, fraction: 0))
                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary).monospacedDigit()

            if onUnlink != nil {
                Menu {
                    Button(role: .destructive) { confirmUnlink = true } label: {
                        Label("Отвязать кошелёк", systemImage: "minus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Действия с кошельком")
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .confirmationDialog("Отвязать «\(wallet.label)»?", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("Отвязать", role: .destructive) { onUnlink?() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Кошелёк только для просмотра, средства не двигаются. Он исчезнет из портфеля, привязать снова можно в любой момент.")
        }
    }
}

#Preview {
    GroupedSection {
        ExternalWalletProviderTile(provider: .metaMask)
        ExternalWalletProviderTile(provider: .ledger)
        ExternalWalletRow(wallet: MockCryptoData.seededExternalWallets[0], valueRub: 612_400)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
