import SwiftUI

/// Mode switcher (§10.9): Поддержка / Финкоуч / Агент. The selected mode uses the cold AI gradient so
/// the copilot reads as "AI", separate from fiat (§13.1).
struct CopilotModePicker: View {
    @Binding var mode: CopilotMode
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CopilotMode.allCases) { item in
                let selected = item == mode
                Button {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { mode = item }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: item.icon).font(.system(size: 12, weight: .semibold))
                        Text(item.title).font(BrandFont.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .foregroundStyle(selected ? .white : theme.textSecondary)
                    .background {
                        if selected {
                            Capsule().fill(theme.cryptoGradient)
                        } else {
                            Capsule().fill(theme.elevated)
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
