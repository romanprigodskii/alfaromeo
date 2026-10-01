import SwiftUI

/// A tappable consent checkbox row, meant to sit inside a ``GroupedSection``.
struct ConsentRow: View {
    @Binding var isOn: Bool
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? theme.accent : theme.textTertiary)
                    .frame(width: 24)
                Text(text)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(36)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
