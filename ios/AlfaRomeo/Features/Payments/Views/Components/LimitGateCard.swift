import SwiftUI

/// A soft gate shown at the amount step when an operation can't proceed (§2.4 / §10.3): превышение
/// лимита операции, or the неквал-инвестор годовой лимит for crypto. Informative, never a dead end:
/// it offers a clear next step (уменьшить сумму / пройти тест инвестора) without dark patterns (§4).
struct LimitGateCard: View {
    enum Kind: Equatable {
        case perOperation(limit: Double)
        case investor(remaining: Double)
    }

    let kind: Kind
    var onAdjust: () -> Void = {}
    var onTakeInvestorTest: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(warningInk)
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            }
            Text(message)
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .investor = kind {
                progress
            }

            HStack(spacing: Spacing.lg) {
                action("Изменить сумму", onAdjust)
                if case .investor = kind {
                    action("Пройти тест инвестора", onTakeInvestorTest)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var warningInk: Color { theme.statusInk(.warning) }

    private func action(_ title: String, _ handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            Text(title)
                .font(BrandFont.body(15, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var progress: some View {
        let used = PaymentsMockData.nonQualUsedThisYearRub
        let limit = PaymentsMockData.nonQualYearlyLimitRub
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            ProgressBar(value: used / limit, tint: theme.warning)
            Text("Использовано \(MoneyFormat.fiat(used)) из \(MoneyFormat.fiat(limit)) в этом году")
                .font(BrandFont.footnote).monospacedDigit().foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var icon: String {
        switch kind {
        case .perOperation: return "gauge.with.dots.needle.bottom.50percent"
        case .investor:     return "checkmark.shield"
        }
    }

    private var title: String {
        switch kind {
        case .perOperation: return "Превышен лимит операции"
        case .investor:     return "Лимит неквал-инвестора"
        }
    }

    private var message: String {
        switch kind {
        case .perOperation(let limit):
            return "Максимум за одну операцию: \(MoneyFormat.fiat(limit)). Уменьшите сумму или повысьте лимит в настройках безопасности."
        case .investor(let remaining):
            return "Неквалифицированным инвесторам доступно \(MoneyFormat.fiat(PaymentsMockData.nonQualYearlyLimitRub)) в год через посредника. Осталось \(MoneyFormat.fiat(remaining)). Пройдите тест, чтобы повысить статус."
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        LimitGateCard(kind: .perOperation(limit: 150_000))
        LimitGateCard(kind: .investor(remaining: 20_000))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
