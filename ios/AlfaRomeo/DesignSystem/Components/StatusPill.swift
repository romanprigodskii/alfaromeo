import SwiftUI

/// Compact status indicator for operation / delivery states (§13.1 animated statuses).
struct StatusPill: View {
    enum Status: String, CaseIterable, Sendable {
        case processing, success, declined, pending, warning

        var label: String {
            switch self {
            case .processing: return "Обработка"
            case .success:    return "Успешно"
            case .declined:   return "Отклонено"
            case .pending:    return "В ожидании"
            case .warning:    return "Внимание"
            }
        }

        var systemImage: String {
            switch self {
            case .processing: return "arrow.triangle.2.circlepath"
            case .success:    return "checkmark.circle.fill"
            case .declined:   return "xmark.circle.fill"
            case .pending:    return "clock.fill"
            case .warning:    return "exclamationmark.triangle.fill"
            }
        }
    }

    var status: Status
    var text: String? = nil

    @Environment(\.theme) private var theme

    // Foreground for the label + icon. In the light scheme the saturated status hues fail AA as
    // text on the pale tinted capsule, so use darker "ink" variants there (§13.1 readability).
    private var color: Color {
        let dark = theme.isDark
        switch status {
        case .processing, .pending: return theme.accent
        case .success:              return dark ? theme.success : BrandColors.successInkLight
        case .declined:             return dark ? theme.danger  : BrandColors.dangerInkLight
        case .warning:              return dark ? theme.warning : BrandColors.warningInkLight
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if status == .processing {
                ProgressView().controlSize(.mini).tint(color)
            } else {
                Image(systemName: status.systemImage).font(.system(size: 11, weight: .bold))
            }
            Text(text ?? status.label).font(BrandFont.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(color.opacity(0.14), in: Capsule())
        .accessibilityLabel(text ?? status.label)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        StatusPill(status: .processing)
        StatusPill(status: .success)
        StatusPill(status: .declined)
        StatusPill(status: .pending)
        StatusPill(status: .warning)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
