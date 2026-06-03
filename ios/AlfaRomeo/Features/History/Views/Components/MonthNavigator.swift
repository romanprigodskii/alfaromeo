import SwiftUI

/// Helper-month stepper for the analytics screen (§9.4 «помесячно — как реф-скрин „Июнь"»).
/// Centered month label flanked by prev/next chevrons; ends disable at the data bounds.
struct MonthNavigator: View {
    let title: String
    var canGoPrev: Bool = true
    var canGoNext: Bool = true
    var onPrev: () -> Void
    var onNext: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            stepper(system: "chevron.left", enabled: canGoPrev, action: onPrev)
            Spacer()
            Text(title)
                .font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.opacity)
            Spacer()
            stepper(system: "chevron.right", enabled: canGoNext, action: onNext)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(theme.surface, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func stepper(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? theme.accent : theme.textSecondary.opacity(0.4))
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    MonthNavigator(title: "Июнь 2035", canGoPrev: true, canGoNext: false, onPrev: {}, onNext: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
