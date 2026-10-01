import SwiftUI

/// A quick action (Пополнить / Перевести / Обмен…), docs/DESIGN.md §5: a 56pt neutral circle with an
/// ink glyph (22pt) and a footnote label below. No gradients, no accent fills.
///
/// Lay several out in an `HStack` (or ``QuickActionRow``) with equal widths:
/// ```swift
/// QuickActionRow {
///     QuickActionButton("Пополнить", systemImage: "plus") { … }
///     QuickActionButton("Перевести", systemImage: "arrow.up.right") { … }
/// }
/// ```
struct QuickActionButton: View {
    let title: String
    let systemImage: String
    /// Circle color. Defaults to `fill`.
    var circle: Color? = nil
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, systemImage: String, circle: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.circle = circle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: GlyphCircle.outlineSymbol(systemImage))
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isEnabled ? theme.textPrimary : theme.textTertiary)
                    .frame(width: 56, height: 56)
                    .background(circle ?? theme.fill, in: Circle())
                Text(title)
                    .font(BrandFont.footnote)
                    .foregroundStyle(isEnabled ? theme.textPrimary : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96))
        .accessibilityLabel(title)
    }
}

/// An evenly spaced row of ``QuickActionButton``s (up to 4–5).
struct QuickActionRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            content()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuickActionRow {
        QuickActionButton("Пополнить", systemImage: "plus") {}
        QuickActionButton("Перевести", systemImage: "arrow.up.right") {}
        QuickActionButton("Обмен", systemImage: "arrow.left.arrow.right") {}
        QuickActionButton("Ещё", systemImage: "ellipsis") {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
