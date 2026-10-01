import SwiftUI

/// Month stepper for the analytics screen (§9.4 «помесячно»). A centred month label flanked by
/// prev/next chevrons in ink, flat on the screen background; ends disable at the data bounds.
struct MonthNavigator: View {
    let title: String
    var canGoPrev: Bool = true
    var canGoNext: Bool = true
    var onPrev: () -> Void
    var onNext: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            stepper(system: "chevron.left", enabled: canGoPrev, label: "Предыдущий месяц", action: onPrev)
            Spacer()
            Text(title)
                .font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.opacity)
            Spacer()
            stepper(system: "chevron.right", enabled: canGoNext, label: "Следующий месяц", action: onNext)
        }
    }

    private func stepper(system: String, enabled: Bool, label: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(enabled ? theme.textPrimary : theme.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    MonthNavigator(title: "Июнь 2035", canGoPrev: true, canGoNext: false, onPrev: {}, onNext: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
