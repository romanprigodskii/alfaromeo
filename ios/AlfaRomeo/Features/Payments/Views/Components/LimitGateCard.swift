import SwiftUI

/// A soft gate shown at the amount step when an operation can't proceed (§2.4 / §10.3): превышение
/// лимита операции, or the неквал-инвестор годовой лимит for crypto. Informative, never a dead end —
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.warning)
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            }
            Text(message)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .investor = kind {
                progress
            }

            HStack(spacing: Spacing.sm) {
                Button(action: onAdjust) {
                    Text("Изменить сумму")
                        .font(BrandFont.callout.weight(.semibold))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 40)
                        .background(theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                if case .investor = kind {
                    Button(action: onTakeInvestorTest) {
                        Text("Пройти тест инвестора")
                            .font(BrandFont.callout.weight(.medium))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            .stroke(theme.warning.opacity(0.55), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var progress: some View {
        let used = PaymentsMockData.nonQualUsedThisYearRub
        let limit = PaymentsMockData.nonQualYearlyLimitRub
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            ProgressBar(value: used / limit, tint: theme.warning)
            Text("Использовано \(Self.rub(used)) из \(Self.rub(limit)) в этом году")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
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
            return "Максимум за одну операцию — \(Self.rub(limit)). Уменьшите сумму или повысьте лимит в настройках безопасности."
        case .investor(let remaining):
            return "Неквалифицированным инвесторам доступно 300 000 ₽ в год через посредника (§2.4). Осталось \(Self.rub(remaining)). Пройдите тест, чтобы повысить статус."
        }
    }

    private static func rub(_ value: Double) -> String {
        (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " ₽"
    }
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 0
        return f
    }()
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
