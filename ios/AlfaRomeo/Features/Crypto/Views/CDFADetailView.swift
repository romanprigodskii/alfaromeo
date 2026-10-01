import SwiftUI

/// ЦФА (детейл) (§9.6 🆕). The legal 259-ФЗ path: эмитент + оператор ИС, доходность, цена в ₽, and a
/// mock buy/hold flow. Crucially **not** gated by the crypto квал/неквал rules or the 300к лимит — only
/// ordinary KYC applies (the user is already verified). ``LegalBadge`` marks the regulated path.
struct CDFADetailView: View {
    let cdfaId: String

    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var showBuy = false
    @State private var unitsText = ""
    @State private var authorizing = false
    @State private var outcome: CryptoOutcome?

    private var cdfa: CDFA? { MockCryptoData.cdfa(cdfaId) }
    private var units: Double { max(0, CryptoFormat.parse(unitsText)) }
    private var owned: Double { store.cfaUnits(cdfaId: cdfaId) }

    var body: some View {
        Group {
            if let cdfa { content(cdfa) } else { ContentUnavailableView("ЦФА не найден", systemImage: "questionmark.folder") }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(cdfa?.ticker ?? "ЦФА")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if let outcome { statusOverlay(outcome) } }
    }

    private func content(_ cdfa: CDFA) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header(cdfa)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    LegalBadge()
                    Text("Легальный цифровой актив по 259-ФЗ. Покупка без крипто-лимитов и теста на риски, только обычный KYC.")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }

                if owned > 0 { holdingCard(cdfa) }
                detailsCard(cdfa)
                aboutCard(cdfa)

                PrimaryButton(title: "Купить ЦФА") {
                    unitsText = CryptoFormat.plain(cdfa.minUnits)
                    showBuy = true
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .bottomSheet(isPresented: $showBuy, detents: [.medium]) { buySheet(cdfa) }
    }

    private func header(_ cdfa: CDFA) -> some View {
        HStack(spacing: Spacing.md) {
            AssetGlyph(symbol: cdfa.ticker, systemImage: cdfa.category.icon, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(cdfa.name).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                Text("\(cdfa.category.label), \(cdfa.ticker)").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: cdfa.priceRub, size: 22)
                Text(CryptoFormat.pct(cdfa.dayChangePct))
                    .font(BrandFont.subheadline)
                    .foregroundStyle(cdfa.dayChangePct >= 0 ? theme.success : theme.danger)
                    .monospacedDigit()
            }
        }
    }

    private func detailsCard(_ cdfa: CDFA) -> some View {
        GroupedSection("Параметры") {
            row("Эмитент", cdfa.issuer)
            row("Оператор ИС", cdfa.operatorName)
            row("Статус", cdfa.registryNote)
            row("Доходность", cdfa.yieldPct > 0 ? cdfa.yieldLabel : "Нет")
            row("Цена за единицу", CryptoFormat.rub(cdfa.priceRub))
        }
    }

    private func aboutCard(_ cdfa: CDFA) -> some View {
        GroupedSection("Об инструменте") {
            Text(cdfa.about).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.rowVertical)
        }
    }

    private func holdingCard(_ cdfa: CDFA) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("В портфеле").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Text("\(CryptoFormat.qty(owned)) ед.").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
            }
            Spacer()
            AmountText(amount: owned * cdfa.priceRub, size: 20)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    // MARK: Buy sheet (mock, KYC-only)

    private func buySheet(_ cdfa: CDFA) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Покупка \(cdfa.ticker)").font(BrandFont.title1).foregroundStyle(theme.textPrimary)
            HStack {
                Text("Количество единиц").font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
                Spacer()
                TextField("0", text: $unitsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.amountFace(22, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 120)
            }
            Divider().overlay(theme.border)
            HStack {
                Text("Итого").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                Text(CryptoFormat.rub(units * cdfa.priceRub)).font(BrandFont.headline).foregroundStyle(theme.textPrimary).monospacedDigit()
            }
            LegalBadge(compact: true)
            PrimaryButton(title: "Купить", icon: "faceid", isLoading: authorizing) {
                Task { await buy(cdfa) }
            }
            .disabled(units < cdfa.minUnits)
        }
    }

    private func buy(_ cdfa: CDFA) async {
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(reason: "Купить \(CryptoFormat.qty(units)) \(cdfa.ticker)")
        authorizing = false
        guard ok else { showBuy = false; outcome = .declined(.canceled); return }
        store.buyCDFA(cdfa, units: units)
        showBuy = false
        outcome = .success
    }

    private func statusOverlay(_ outcome: CryptoOutcome) -> some View {
        CryptoStatusView(
            outcome: outcome,
            successTitle: "ЦФА в портфеле",
            successDetail: "Покупка \(cdfa?.ticker ?? "ЦФА") исполнена. Инструмент добавлен в портфель.",
            amount: units, currency: "ед.",
            onRetry: { self.outcome = nil; showBuy = true },
            onClose: { self.outcome = nil }
        )
        .background(theme.background.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        CDFADetailView(cdfaId: "cfa_bond26")
            .environment(\.theme, .default)
    }
}
