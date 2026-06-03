import SwiftUI

/// A capsule filter chip used as the label of the «Счета» / «Даты» menus in the feed header.
/// Reads as "active" (accent-tinted) when a non-default value is selected.
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var isActive: Bool = false
    var showsChevron: Bool = true

    @Environment(\.theme) private var theme

    private var fg: Color { isActive ? theme.accent : theme.textSecondary }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            }
            Text(title).font(BrandFont.caption.weight(.semibold)).lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            (isActive ? theme.accent.opacity(0.16) : theme.elevated),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isActive ? theme.accent.opacity(0.5) : theme.border, lineWidth: 1)
        )
        .contentShape(Capsule())
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        FilterChip(title: "Все счета", icon: "creditcard")
        FilterChip(title: "Этот месяц", icon: "calendar", isActive: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
