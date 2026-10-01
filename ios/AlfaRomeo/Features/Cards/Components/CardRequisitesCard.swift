import SwiftUI
import UIKit

/// Card requisites with show/hide (§6.3). Masked by default; revealing flips PAN / срок / CVC and lets
/// the user copy the number. Demo values only: the real PAN never leaves the server (§11.8).
struct CardRequisitesCard: View {
    let card: CardItem
    @Binding var revealed: Bool

    @Environment(\.theme) private var theme
    @State private var copied: String?

    private var req: CardRequisites { card.requisites }

    var body: some View {
        GroupedSection("Реквизиты",
                       actionTitle: revealed ? "Скрыть" : "Показать",
                       action: { withAnimation(Motion.snappy) { revealed.toggle() } },
                       footer: revealed ? "Демо-данные, не настоящие реквизиты." : nil) {
            row(label: "Номер карты",
                value: revealed ? req.fullPan : req.maskedPan,
                copyValue: revealed ? req.fullPan.replacingOccurrences(of: " ", with: "") : nil)

            HStack(spacing: Spacing.xl) {
                field(label: "Срок", value: revealed ? req.expiry : "••/••")
                field(label: "CVC", value: revealed ? req.cvv : "•••")
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.rowVertical)
        }
    }

    private func row(label: String, value: String, copyValue: String?) -> some View {
        HStack {
            field(label: label, value: value)
            Spacer(minLength: Spacing.sm)
            if let copyValue {
                Button {
                    UIPasteboard.general.string = copyValue
                    withAnimation(Motion.snappy) { copied = label }
                } label: {
                    Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 17))
                        .foregroundStyle(copied == label ? theme.success : theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Скопировать \(label)")
            }
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private func field(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            Text(value)
                .font(BrandFont.code(17, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.identity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
