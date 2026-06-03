import SwiftUI

/// Network selection with a mock fee preview (§10.8 «выбор сети · превью комиссии сети»). Each option
/// shows the network, ETA, and ₽ fee; a congested network carries a warning so the «сеть перегружена»
/// edge case is visible before sending.
struct NetworkFeePicker: View {
    let networks: [CryptoNetwork]
    @Binding var selected: CryptoNetwork?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Сеть").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            VStack(spacing: Spacing.sm) {
                ForEach(networks) { network in
                    row(network)
                }
            }
        }
    }

    private func row(_ network: CryptoNetwork) -> some View {
        let isSelected = selected?.id == network.id
        return Button {
            selected = network
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isSelected ? (theme.accentCrypto.first ?? theme.accent) : theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(network.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        if network.congested {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9, weight: .bold))
                                Text("перегружена").font(BrandFont.micro.weight(.semibold))
                            }
                            .foregroundStyle(theme.warning)
                        }
                    }
                    Text(network.etaLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CryptoFormat.rub(network.feeRub, fraction: 0))
                        .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary).monospacedDigit()
                    Text("комиссия сети").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(isSelected ? (theme.accentCrypto.first ?? theme.accent) : theme.border,
                        lineWidth: isSelected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
