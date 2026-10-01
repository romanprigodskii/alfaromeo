import SwiftUI

/// Шаблоны / Автоплатежи (§9.2). Saved templates launch their rail in one tap; autopayments list
/// with an on/off toggle. «+» opens ``NewTemplateView``. Demo state is in-memory.
struct TemplatesView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var autopayments = PaymentsMockData.autopayments
    private let templates = PaymentsMockData.templates

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                templatesSection
                autopaymentsSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Шаблоны и автоплатежи")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(PaymentsRoute.newTemplate) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Создать")
            }
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        GroupedSection("Шаблоны") {
            ForEach(templates) { template in
                Button { router.push(PaymentsRoute.transfer(template.kind)) } label: {
                    ListRow(icon: template.icon, title: template.title,
                            subtitle: template.detail,
                            value: template.amount.map { MoneyFormat.fiat($0) }, showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: Autopayments

    private var autopaymentsSection: some View {
        GroupedSection("Автоплатежи") {
            ForEach($autopayments) { $auto in
                autoRow($auto)
            }
        }
    }

    private func autoRow(_ auto: Binding<Autopayment>) -> some View {
        let item = auto.wrappedValue
        return HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: item.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(scheduleText(item))
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            Toggle(item.title, isOn: auto.isOn).labelsHidden().tint(theme.accent)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    /// «600 ₽ в месяц · 1 июля», or «5 000 ₽ по порогу» when the payment fires by event.
    private func scheduleText(_ auto: Autopayment) -> String {
        let cadence: String
        switch auto.schedule {
        case .monthly:     cadence = "в месяц"
        case .weekly:      cadence = "в неделю"
        case .byThreshold: cadence = "по порогу"
        }
        let head = "\(MoneyFormat.fiat(auto.amount)) \(cadence)"
        guard let date = Self.isoDate.date(from: auto.nextDate) else { return head }
        return "\(head) · \(Self.dayMonth.string(from: date))"
    }

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()
}
