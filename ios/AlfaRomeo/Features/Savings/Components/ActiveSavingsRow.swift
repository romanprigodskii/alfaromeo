import SwiftUI

/// One active вклад / стейк in the hub list (§10.6 «Список активных вкладов/стейков»). Stakes show
/// their unit amount + a live ₽ valuation; ruble deposits show principal + term.
struct ActiveSavingsRow: View {
    let deposit: Deposit
    let valueRub: Double      // computed by the hub (live price for stakes)
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            ListRow(icon: icon, iconTint: tint, title: title, subtitle: subtitle,
                    value: SavingsFormat.rub(valueRub), showsChevron: true)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var isStake: Bool { deposit.kind == .stake }
    private var icon: String { isStake ? "bitcoinsign.circle.fill" : "banknote.fill" }
    private var tint: Color { isStake ? (theme.accentCrypto.first ?? theme.accent) : theme.success }

    private var title: String {
        isStake ? "Стейкинг \(deposit.asset ?? "")" : "Рублёвый вклад"
    }

    private var subtitle: String {
        var parts: [String] = []
        if isStake { parts.append(SavingsFormat.units(deposit.principal, asset: deposit.asset ?? "")) }
        parts.append(SavingsFormat.percent(deposit.rateApy) + " годовых")
        if let term = deposit.term { parts.append("\(term) мес") }
        else if isStake, deposit.lockUntil != nil { parts.append("lock") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    VStack(spacing: 0) {
        ActiveSavingsRow(deposit: Deposit(id: "d1", profileId: "p", kind: .ruble, asset: nil,
                                          principal: 500_000, rateApy: 16.5, term: 6,
                                          lockUntil: nil), valueRub: 500_000) {}
        ActiveSavingsRow(deposit: Deposit(id: "d2", profileId: "p", kind: .stake, asset: "ETH",
                                          principal: 1.0, rateApy: 4.2, term: nil,
                                          lockUntil: "2035-09-01T00:00:00Z"), valueRub: 318_000) {}
    }
    .padding()
    .environment(\.theme, .default)
}
