import SwiftUI

/// The 2-of-N signature stepper (§11.8): one node per signature slot — filled + checkmarked when
/// signed, hollow + dashed while awaiting — joined by a connecting rail. Reads ``SignatureSlot``s
/// resolved by ``TeamStore``.
struct SignatureProgressView: View {
    let slots: [SignatureSlot]
    var rejected: Bool = false

    @Environment(\.theme) private var theme

    private var signedColor: Color { theme.isDark ? theme.success : BrandColors.successInkLight }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                node(slot)
                if index < slots.count - 1 { rail(after: slot) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func node(_ slot: SignatureSlot) -> some View {
        let signed = slot.phase == .signed
        let tint = rejected ? theme.danger : (signed ? signedColor : theme.textSecondary)
        return VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(signed ? tint.opacity(0.16) : theme.elevated)
                    .frame(width: 44, height: 44)
                Circle()
                    .strokeBorder(signed ? tint : theme.border,
                                  style: StrokeStyle(lineWidth: 2, dash: signed ? [] : [4, 3]))
                    .frame(width: 44, height: 44)
                if signed {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                } else {
                    Text(slot.initials).font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
                }
            }
            Text(slot.name.split(separator: " ").first.map(String.init) ?? slot.name)
                .font(BrandFont.micro).foregroundStyle(theme.textPrimary).lineLimit(1)
            Text(slot.roleLabel)
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary).lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func rail(after slot: SignatureSlot) -> some View {
        Rectangle()
            .fill(slot.phase == .signed && !rejected ? signedColor : theme.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.top, 21)
    }
}

#Preview {
    SignatureProgressView(slots: [
        SignatureSlot(id: "1", name: "Алексей Орлов", initials: "АО", roleLabel: "Владелец", phase: .signed),
        SignatureSlot(id: "2", name: "Мария Кузнецова", initials: "МК", roleLabel: "Бухгалтер", phase: .awaiting),
    ])
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.resolve(for: .business, scheme: .light).background)
    .environment(\.theme, .resolve(for: .business, scheme: .light))
}
