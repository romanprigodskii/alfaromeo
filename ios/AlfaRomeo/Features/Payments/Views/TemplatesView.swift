import SwiftUI

/// Шаблоны / Автоплатежи (§9.2). Saved templates launch their rail in one tap; autopayments list
/// with an on/off toggle. «+ Создать» opens ``NewTemplateView``. Demo state is in-memory.
struct TemplatesView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var autopayments = PaymentsMockData.autopayments
    private let templates = PaymentsMockData.templates

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                templatesSection
                autopaymentsSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Шаблоны")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(PaymentsRoute.newTemplate) } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Шаблоны")
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                        Button { router.push(PaymentsRoute.transfer(template.kind)) } label: {
                            ListRow(icon: template.icon, title: template.title,
                                    subtitle: template.detail,
                                    value: template.amount.map(BillerListView.rub), showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        if index < templates.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    // MARK: Autopayments

    private var autopaymentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Автоплатежи")
            SurfaceCard(padding: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    ForEach($autopayments) { $auto in
                        autoRow($auto)
                        if auto.id != autopayments.last?.id { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    private func autoRow(_ auto: Binding<Autopayment>) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: auto.wrappedValue.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(auto.wrappedValue.title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Text("\(auto.wrappedValue.schedule.label) · \(BillerListView.rub(auto.wrappedValue.amount)) · \(auto.wrappedValue.nextDate)")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Toggle("", isOn: auto.isOn).labelsHidden().tint(theme.accent)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(BrandFont.micro).tracking(1.5).foregroundStyle(theme.textSecondary)
    }
}
