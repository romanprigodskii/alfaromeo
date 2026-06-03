import SwiftUI

/// One explainable decision factor (§10.5 «факторы решения»): label + status + a contribution bar,
/// tappable to reveal the plain-language «почему так» and a «что улучшить» hint. The bar fill is the
/// factor's support for the limit, colored by status — so the weak factor visibly drags.
struct FactorRow: View {
    let factor: DecisionFactor
    @State private var expanded = false

    @Environment(\.theme) private var theme

    private var statusColor: Color {
        switch factor.status {
        case .good: return theme.success
        case .ok:   return theme.warning
        case .weak: return theme.danger
        }
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    withAnimation(Motion.snappy) { expanded.toggle() }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle().fill(statusColor.opacity(0.14)).frame(width: 38, height: 38)
                            Image(systemName: factor.kind.systemImage)
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(statusColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(factor.kind.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                                Spacer()
                                statusBadge
                            }
                            HStack {
                                Text(factor.valueLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                Spacer()
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())

                ProgressBar(value: factor.contribution, tint: statusColor, height: 6)

                if expanded {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(factor.explanation)
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let improvement = factor.improvement {
                            HStack(alignment: .top, spacing: Spacing.xs) {
                                Image(systemName: "lightbulb.fill").font(.system(size: 11))
                                    .foregroundStyle(theme.accent)
                                Text(improvement).font(BrandFont.caption.weight(.medium))
                                    .foregroundStyle(theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(factor.status.label)
            .font(BrandFont.micro.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
            .background(statusColor.opacity(0.14), in: Capsule())
    }
}
