import SwiftUI

/// Delivery progress (§6.2 оформлена, печать, в пути, доставлена). Completed stages get a check, the
/// current stage is filled, the connecting track fills as the status advances.
struct DeliveryStepper: View {
    let status: PhysicalCardStatus

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stages = PhysicalCardStatus.deliveryStages
    private let nodeSize: CGFloat = 32

    private var current: Int { status.stageIndex }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                column(index: index, stage: stage)
                if index < stages.count - 1 {
                    connector(filled: index < current)
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.progress, value: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Статус доставки: \(status.title)")
    }

    private func column(index: Int, stage: PhysicalCardStatus) -> some View {
        let isDone = index < current
        let isCurrent = index == current
        let active = isDone || isCurrent
        return VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(active ? theme.accent : theme.fill)
                    .frame(width: nodeSize, height: nodeSize)
                Image(systemName: isDone ? "checkmark" : GlyphCircle.outlineSymbol(stage.icon))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? theme.onAccent : theme.textSecondary)
            }
            Text(stage.title)
                .font(BrandFont.footnote.weight(isCurrent ? .medium : .regular))
                .foregroundStyle(active ? theme.textPrimary : theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 66)
    }

    private func connector(filled: Bool) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(theme.fill)
            Capsule().fill(theme.accent).scaleEffect(x: filled ? 1 : 0, anchor: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 2)
        .frame(height: nodeSize) // center the track vertically against the node row
    }
}

#Preview {
    VStack(spacing: Spacing.section) {
        DeliveryStepper(status: .ordered)
        DeliveryStepper(status: .printing)
        DeliveryStepper(status: .shipping)
        DeliveryStepper(status: .delivered)
    }
    .padding(Spacing.screen)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
