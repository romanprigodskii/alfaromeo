import SwiftUI

/// Network selection with a mock fee preview (§10.8 «выбор сети · превью комиссии сети»). Each option
/// shows the network, ETA, and ₽ fee; a congested network carries a warning so the «сеть перегружена»
/// edge case is visible before sending.
struct NetworkFeePicker: View {
    let networks: [CryptoNetwork]
    @Binding var selected: CryptoNetwork?

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection("Сеть") {
            ForEach(networks) { network in
                row(network)
            }
        }
    }

    private func row(_ network: CryptoNetwork) -> some View {
        let isSelected = selected?.id == network.id
        return Button {
            selected = network
        } label: {
            HStack(spacing: ListRow.glyphSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(network.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    HStack(spacing: Spacing.xs) {
                        Text(network.etaLabel)
                        if network.congested {
                            Text("перегружена").foregroundStyle(theme.statusInk(.warning))
                        }
                    }
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CryptoFormat.rub(network.feeRub, fraction: 0))
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary).monospacedDigit()
                    Text("комиссия").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 20)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NetworkFeePicker(networks: CryptoCatalog.networks(for: "USDT"),
                     selected: .constant(CryptoCatalog.networks(for: "USDT").first))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
