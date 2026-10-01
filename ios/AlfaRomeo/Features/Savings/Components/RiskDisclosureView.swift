import SwiftUI

/// Mandatory risk-acknowledgement block for the staking flow (§10.6: «обязательный чекбокс перед
/// стейком»). The confirm button stays disabled until `accepted` is true. The hub states the same
/// АСВ-vs-рыночный-риск contrast in its section footers, before the user picks a product.
struct StakeRiskDisclosure: View {
    @Binding var accepted: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GroupedSection {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Это не вклад")
                        .font(BrandFont.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(SavingsRisk.marketRisk.detail)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Spacing.rowVertical)

                bullet("Средства не застрахованы АСВ", "xmark.shield")
                bullet("Цена актива меняется, тело может уменьшиться", "chart.line.downtrend.xyaxis")
                bullet("Только BTC, ETH и стейблкоины", "checkmark.seal")
            }

            Button { accepted.toggle() } label: {
                HStack(alignment: .top, spacing: Spacing.sm + 4) {
                    Image(systemName: accepted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(accepted ? theme.accent : theme.textTertiary)
                    Text("Я понимаю рыночный риск и что стейкинг не застрахован государством")
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(accepted ? .isSelected : [])
            .animation(Motion.snappy, value: accepted)
        }
    }

    private func bullet(_ text: String, _ icon: String) -> some View {
        HStack(spacing: Spacing.sm + 4) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 24)
            Text(text)
                .font(BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(36)
    }
}

#Preview {
    struct Demo: View {
        @State var ok = false
        var body: some View {
            ScrollView {
                StakeRiskDisclosure(accepted: $ok).padding()
            }
            .background(Theme.default.background)
        }
    }
    return Demo().environment(\.theme, .default)
}
