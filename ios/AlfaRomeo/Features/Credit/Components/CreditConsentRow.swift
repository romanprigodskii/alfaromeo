import SwiftUI

/// A single required consent in the credit-application flow (§10.5 «согласия»): a tappable checkbox +
/// label. Used for the БКИ request, personal-data processing and the individual contract terms.
/// (Named `Credit…` to avoid colliding with the Auth onboarding's own `ConsentRow`.)
struct CreditConsentRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { isOn.toggle() }
        } label: {
            HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? theme.accent : theme.textTertiary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(24 + ListRow.glyphSpacing)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityLabel(title)
    }
}
