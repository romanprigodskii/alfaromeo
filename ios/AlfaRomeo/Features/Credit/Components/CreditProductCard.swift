import SwiftUI

/// A product on the кредитная витрина (§10.5 наличные / карта / рассрочка) showing its pre-approved
/// amount, personalised rate and key terms, with «Оформить» as the call-to-action.
struct CreditProductCard: View {
    let product: CreditProduct
    let approvedLimit: Double
    let rate: Double
    var onApply: () -> Void

    @Environment(\.theme) private var theme

    private var approved: Bool { approvedLimit > 0 }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                Divider().overlay(theme.border)
                numbers
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(product.highlights, id: \.self) { line in
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.accent)
                            Text(line).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                PrimaryButton(title: approved ? "Оформить" : "Узнать условия",
                              icon: approved ? "arrow.right" : "info.circle", action: onApply)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(theme.accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: product.kind.systemImage)
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(product.tagline).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var numbers: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(approved ? "Преодобрено" : product.kind.amountNoun)
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                if approved {
                    AmountText(amount: approvedLimit, size: 22)
                } else {
                    Text("до \(CreditFormat.rub(product.maxAmount))")
                        .font(BrandFont.mono(20, weight: .semibold)).foregroundStyle(theme.textPrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Ставка").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                Text(product.kind.isInterestFree ? "0%" : CreditFormat.rate(rate))
                    .font(BrandFont.mono(20, weight: .semibold)).foregroundStyle(theme.textPrimary)
            }
        }
    }
}
