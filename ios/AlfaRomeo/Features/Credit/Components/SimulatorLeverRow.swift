import SwiftUI

/// A what-if lever in the pre-qual simulator (§10.5 «если закрыть карту X — лимит +Y»). Shows the
/// exact derived Δ to the limit from toggling it; tapping applies it and the hero ``LimitGauge``
/// animates to the new amount.
struct SimulatorLeverRow: View {
    let lever: SimulatorLever
    let delta: Double            // exact Δ to the approved limit (derived, signed)
    let isOn: Bool
    var onToggle: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill((isOn ? theme.accent : theme.textSecondary).opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: lever.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? theme.accent : theme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lever.title).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text(lever.subtitle).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 4) {
                    // Applied levers are already folded into the limit; the row's tap REMOVES them, so a
                    // green «+Δ» would be misleading. Show «учтено» when on, the potential gain when off.
                    if isOn {
                        Text("учтено")
                            .font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.accent)
                    } else if delta > 0 {
                        Text(CreditFormat.signedRub(delta))
                            .font(BrandFont.mono(14, weight: .semibold)).foregroundStyle(theme.success)
                    } else {
                        Text("—").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18)).foregroundStyle(isOn ? theme.accent : theme.border)
                }
            }
            .padding(Spacing.sm)
            .background(isOn ? theme.accent.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(isOn ? theme.accent.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(lever.title), \(isOn ? "включено" : "выключено"), эффект \(CreditFormat.signedRub(delta))")
    }
}
