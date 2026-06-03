import SwiftUI

/// Разбивка использования (§7.2): столбики по дням + список категорий с долями. Pure presentation —
/// the data comes from ``MobileUsage`` (mock).
struct UsageBreakdownView: View {
    let usage: MobileUsage

    @Environment(\.theme) private var theme

    private var maxDayGb: Double { max(usage.peakGb, 0.1) }
    private var lastDayId: Int { usage.days.last?.id ?? -1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("По дням").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    ForEach(usage.days) { day in
                        VStack(spacing: Spacing.xs) {
                            Text(format(day.gb)).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                                .fill(theme.accent.opacity(day.id == lastDayId ? 1 : 0.5))
                                .frame(height: max(6, CGFloat(day.gb / maxDayGb) * 96))
                            Text(day.label).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 140, alignment: .bottom)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("По категориям").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(usage.categories.enumerated()), id: \.element.id) { i, cat in
                            categoryRow(cat)
                            if i < usage.categories.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(_ cat: MobileUsageCategory) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                Image(systemName: cat.icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent).frame(width: 28)
                Text(cat.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(format(cat.gb)) ГБ").font(BrandFont.callout.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Text("\(Int(cat.share * 100))%").font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary).frame(width: 40, alignment: .trailing)
            }
            ProgressBar(value: cat.share, height: 5)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func format(_ value: Double) -> String { MobileTariff.format(value) }
}
