import SwiftUI

/// Разбивка использования (§7.2): столбики по дням + список категорий с долями. Pure presentation;
/// the data comes from ``MobileUsage`` (mock).
struct UsageBreakdownView: View {
    let usage: MobileUsage

    @Environment(\.theme) private var theme

    private var maxDayGb: Double { max(usage.peakGb, 0.1) }
    private var lastDayId: Int { usage.days.last?.id ?? -1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                SectionHeader("По дням")
                SurfaceCard {
                    HStack(alignment: .bottom, spacing: Spacing.sm) {
                        ForEach(usage.days) { day in
                            VStack(spacing: Spacing.xs) {
                                Text(format(day.gb)).font(BrandFont.micro).monospacedDigit()
                                    .foregroundStyle(theme.textSecondary)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(day.id == lastDayId ? theme.accent : theme.textTertiary.opacity(0.55))
                                    .frame(height: max(6, CGFloat(day.gb / maxDayGb) * 96))
                                Text(day.label).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140, alignment: .bottom)
                }
            }

            GroupedSection("По категориям") {
                ForEach(usage.categories) { cat in
                    categoryRow(cat)
                }
            }
        }
    }

    private func categoryRow(_ cat: MobileUsageCategory) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: cat.icon)
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(cat.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    Text(format(cat.gb) + "\u{00A0}ГБ").font(BrandFont.bodyM).monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                    Text(MoneyFormat.percent(fraction: cat.share, maxFractionDigits: 0))
                        .font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 44, alignment: .trailing)
                }
                ProgressBar(value: cat.share, height: 4)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    private func format(_ value: Double) -> String { MobileTariff.format(value) }
}
