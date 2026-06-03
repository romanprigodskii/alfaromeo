import SwiftUI
import UIKit

/// Card requisites with a show/hide «глаз» (§6.3). Masked by default; revealing flips PAN / срок /
/// CVC and lets the user copy them. Demo values only — the real PAN never leaves the server (§11.8).
struct CardRequisitesCard: View {
    let card: CardItem
    @Binding var revealed: Bool

    @Environment(\.theme) private var theme
    @State private var copied: String?

    private var req: CardRequisites { card.requisites }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label("Реквизиты карты", systemImage: "lock.shield")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(Motion.snappy) { revealed.toggle() }
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 36, height: 36)
                            .background(theme.elevated, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealed ? "Скрыть реквизиты" : "Показать реквизиты")
                }

                row(label: "Номер карты",
                    value: revealed ? req.fullPan : req.maskedPan,
                    copyValue: revealed ? req.fullPan.replacingOccurrences(of: " ", with: "") : nil)

                HStack(spacing: Spacing.xl) {
                    field(label: "Срок", value: revealed ? req.expiry : "••/••")
                    field(label: "CVC", value: revealed ? req.cvv : "•••")
                    Spacer()
                }

                Text(revealed
                     ? "Демо-данные. Не настоящие реквизиты."
                     : "Скрыто. Нажмите «глаз», чтобы показать.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func row(label: String, value: String, copyValue: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            HStack {
                Text(value)
                    .font(BrandFont.mono(18, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.identity)
                Spacer()
                if let copyValue {
                    Button {
                        UIPasteboard.general.string = copyValue
                        withAnimation(Motion.snappy) { copied = label }
                    } label: {
                        Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(copied == label ? theme.success : theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Скопировать \(label)")
                }
            }
        }
    }

    private func field(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            Text(value).font(BrandFont.mono(18, weight: .medium)).foregroundStyle(theme.textPrimary)
        }
    }
}
