import SwiftUI

/// ЦФА (детейл) (§9.6 🆕). The legal 259-ФЗ path: эмитент + оператор ИС, доходность, цена в ₽, and a
/// mock buy/hold flow. Crucially **not** gated by the crypto квал/неквал rules or the 300к лимит — only
/// ordinary KYC applies (the user is already verified). Cold gradient + ``LegalBadge`` mark the family.
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
                HStack { LegalBadge(); Spacer() }
                Text("Это ЦФА — легальный цифровой актив по 259-ФЗ. Покупка без крипто-лимитов и теста на риски, только обычный KYC.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)

                detailsCard(cdfa)
                aboutCard(cdfa)
                if owned > 0 { holdingCard(cdfa) }

                PrimaryButton(title: "Купить ЦФА", icon: "cart.fill") {
                    unitsText = CryptoFormat.plain(cdfa.minUnits)
                    showBuy = true
                }
            }
            .padding(.horizontal, Spacing.lg)
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
                Text(cdfa.name).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("\(cdfa.category.label) · \(cdfa.ticker)").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: cdfa.priceRub, size: 22)
                Text(CryptoFormat.pct(cdfa.dayChangePct))
                    .font(BrandFont.callout.weight(.semibold))
                    .foregroundStyle(cdfa.dayChangePct >= 0 ? theme.success : theme.danger)
            }
        }
    }

    private func detailsCard(_ cdfa: CDFA) -> some View {
        SurfaceCard {
            VStack(spacing: 0) {
                row("Эмитент", cdfa.issuer)
                Divider().overlay(theme.border)
                row("Оператор ИС", cdfa.operatorName)
                Divider().overlay(theme.border)
                row("Статус", cdfa.registryNote, accent: true)
                Divider().overlay(theme.border)
                row("Доходность", cdfa.yieldPct > 0 ? cdfa.yieldLabel : "—")
                Divider().overlay(theme.border)
                row("Цена за единицу", CryptoFormat.rub(cdfa.priceRub))
            }
        }
    }

    private func aboutCard(_ cdfa: CDFA) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Об инструменте").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(cdfa.about).font(BrandFont.callout).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func holdingCard(_ cdfa: CDFA) -> some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("В портфеле").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Text("\(CryptoFormat.qty(owned)) ед.").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }
                Spacer()
                AmountText(amount: owned * cdfa.priceRub, size: 20)
            }
        }
    }

    private func row(_ label: String, _ value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(BrandFont.callout.weight(.medium))
                .foregroundStyle(accent ? (theme.accentCrypto.first ?? theme.accent) : theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Buy sheet (mock, KYC-only)

    private func buySheet(_ cdfa: CDFA) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Покупка \(cdfa.ticker)").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            HStack {
                Text("Количество единиц").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                Spacer()
                TextField("0", text: $unitsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.mono(20, weight: .medium))
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
            PrimaryButton(title: "Купить · Face ID", icon: "faceid", isLoading: authorizing) {
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
