import SwiftUI

/// Operation / delivery state (docs/DESIGN.md §5): caption 12 medium, radius 8. Tinted only by the
/// state it reports: success green, declined red, pending / warning amber, processing neutral with a
/// small spinner. No decorative icons.
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

        /// Kept for callers that draw their own status glyph.
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

    private var role: Theme.StatusRole? {
        switch status {
        case .processing:         return nil
        case .success:            return .success
        case .declined:           return .danger
        case .pending, .warning:  return .warning
        }
    }

    private var foreground: Color { role.map { theme.statusInk($0) } ?? theme.textSecondary }

    private var background: Color {
        switch role {
        case .success: return theme.success.opacity(theme.isDark ? 0.22 : 0.14)
        case .danger:  return theme.danger.opacity(theme.isDark ? 0.22 : 0.12)
        case .warning: return theme.warning.opacity(theme.isDark ? 0.22 : 0.16)
        case nil:      return theme.fill
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if status == .processing {
                ProgressView().controlSize(.mini).tint(foreground)
            }
            Text(text ?? status.label)
                .font(BrandFont.micro)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text ?? status.label)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ForEach(StatusPill.Status.allCases, id: \.self) { StatusPill(status: $0) }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
