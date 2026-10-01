import SwiftUI

/// Трейдинг/ордер (§9.6): маркет/лимит, превью, подтверждение, исполнение (симуляция). Market orders
/// fill at the live rate + tier spread (with a TTL re-quote on staleness); limit orders are placed
/// open at the user's price. Gated for неквал by the risk test + 300к лимит.
struct TradeOrderView: View {
    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var model: TradeOrderModel
    @State private var store = CryptoStore.shared
    @State private var prices = LivePriceService.shared
    @State private var showRiskTest = false

    init(symbol: String, side: CryptoSide, prefilledPrice: Double? = nil) {
        _model = State(initialValue: TradeOrderModel(symbol: symbol, side: side, prefilledPrice: prefilledPrice))
    }

    private var investorStatus: InvestorStatus { session.currentUser?.investorStatus ?? .unqualified }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !CryptoCatalog.isTradable(model.symbol) {
                    notTradableNote
                } else {
                    switch model.step {
                    case .form:    formStep
                    case .confirm: confirmStep
                    case .status:  EmptyView()
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Ордер \(model.symbol)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.step == .status { statusOverlay } }
        .task { await model.load(api: api, session: session) }
        .onAppear { if store.requiresRiskTest(investorStatus: investorStatus) { showRiskTest = true } }
        .bottomSheet(isPresented: $showRiskTest, detents: [.large]) {
            RiskTestSheet(onPass: { store.passRiskTest(); showRiskTest = false },
                          onCancel: { showRiskTest = false; dismiss() })
        }
    }

    // MARK: Non-tradable guard (§2.4)

    private var notTradableNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 17, weight: .regular))
                .foregroundStyle(theme.statusInk(.warning))
            VStack(alignment: .leading, spacing: 2) {
                Text("Торговля недоступна").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("\(model.symbol) нельзя торговать в РФ-режиме. Доступны BTC, ETH, TON и стейблкоины. Актив можно держать и просматривать.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Form

    private var formStep: some View {
        VStack(spacing: Spacing.md) {
            assetHeader

            TradeSideToggle(side: $model.side)

            Picker("", selection: $model.orderType) {
                Text("Рыночный").tag(OrderType.market)
                Text("Лимитный").tag(OrderType.limit)
            }.pickerStyle(.segmented)

            priceField
            TicketField(label: "Количество", text: qtyBinding, unit: model.symbol,
                        step: qtyStep, onStep: stepQty)
            TicketField(label: "Объём", text: totalBinding, unit: "₽")

            availableLine

            PercentSelector(fraction: percentBinding)

            advancedOptions

            gateView

            if model.orderType == .market && model.spreadTier == .standard {
                UpsellCard(title: "Спред ниже на Pro",
                           message: "На Pro и Infinite спред на сделках меньше.",
                           recommendedTier: .pro)
            }

            TradeActionButton(title: model.side == .buy ? "Купить \(model.symbol)" : "Продать \(model.symbol)",
                              side: model.side) { model.goToConfirm() }
                .disabled(!model.canProceed)
        }
        .onChange(of: model.orderType) { model.syncTotalFromQty() }
        .onChange(of: model.side) { model.syncTotalFromQty() }
        .onChange(of: model.limitPriceText) { model.syncTotalFromQty() }
    }

    private var assetHeader: some View {
        HStack(spacing: Spacing.md) {
            AssetGlyph(symbol: model.symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(CryptoCatalog.name(model.symbol)).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Live: \(CryptoFormat.rub(model.midPrice))").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
        }
    }

    // MARK: Ticket fields (Цена / Количество / Объём)

    @ViewBuilder private var priceField: some View {
        if model.orderType == .limit {
            TicketField(label: "Цена", text: $model.limitPriceText, unit: "₽",
                        step: priceStep, onStep: stepLimit)
        } else {
            TicketField(label: "Цена", text: .constant("Рыночная"), unit: "", enabled: false)
        }
    }

    private var availableLine: some View {
        Text(model.side == .buy
             ? "Доступно \(CryptoFormat.rub(model.rubAvailable))"
             : "Доступно \(CryptoFormat.qty(model.balance, symbol: model.symbol))")
            .font(BrandFont.subheadline)
            .foregroundStyle(model.insufficientFunds ? theme.statusInk(.danger) : theme.textSecondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var qtyBinding: Binding<String> {
        Binding(get: { model.amountText }, set: { model.setQty($0) })
    }
    private var totalBinding: Binding<String> {
        Binding(get: { model.totalText }, set: { model.setTotal($0) })
    }
    private var percentBinding: Binding<Double> {
        Binding(get: { model.percentFraction }, set: { model.applyPercent($0) })
    }

    /// Tick sizes scale with the asset's price magnitude (BTC steps coarser than a stablecoin).
    private var priceStep: Double {
        let m = model.midPrice
        if m >= 1_000_000 { return 10_000 }
        if m >= 100_000 { return 1_000 }
        if m >= 1_000 { return 10 }
        return 0.1
    }
    private var qtyStep: Double {
        let m = model.midPrice
        if m >= 1_000_000 { return 0.001 }
        if m >= 100_000 { return 0.01 }
        if m >= 1_000 { return 0.1 }
        return 10
    }
    private func stepLimit(_ delta: Double) {
        model.limitPriceText = CryptoFormat.plain(max(0, CryptoFormat.parse(model.limitPriceText) + delta))
    }
    private func stepQty(_ delta: Double) {
        model.setQty(CryptoFormat.plain(max(0, CryptoFormat.parse(model.amountText) + delta)))
    }

    // MARK: Advanced spot options (TP/SL · Post-Only · GTC) — visual order parameters, no leverage

    private var advancedOptions: some View {
        GroupedSection {
            VStack(spacing: Spacing.sm) {
                optionToggle("Тейк-профит (TP)", isOn: $model.tpEnabled)
                if model.tpEnabled {
                    TicketField(label: "Цена TP", text: $model.tpPriceText, unit: "₽")
                }
            }
            .padding(.vertical, Spacing.sm)
            VStack(spacing: Spacing.sm) {
                optionToggle("Стоп-лосс (SL)", isOn: $model.slEnabled)
                if model.slEnabled {
                    TicketField(label: "Цена SL", text: $model.slPriceText, unit: "₽")
                }
            }
            .padding(.vertical, Spacing.sm)
            if model.orderType == .limit {
                optionToggle("Post-Only", isOn: $model.postOnly)
                    .padding(.vertical, Spacing.sm)
                optionToggle("GTC, до отмены", isOn: $model.goodTillCanceled)
                    .padding(.vertical, Spacing.sm)
            }
        }
    }

    private func optionToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
        }
        .tint(theme.accent)
    }

    @ViewBuilder private var gateView: some View {
        if case .investorLimit(let remaining) = model.gate {
            LimitGateCard(kind: .investor(remaining: remaining),
                          onAdjust: { model.amountText = "" },
                          onTakeInvestorTest: { router.push(CryptoRoute.investorStatus) })
        }
    }

    // MARK: Confirm

    @ViewBuilder private var confirmStep: some View {
        if model.usesQuote {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let expired = model.quoteExpired(at: context.date)
                confirmContent(expired: expired, remaining: model.quoteRemaining(at: context.date))
            }
        } else {
            confirmContent(expired: false, remaining: 0)
        }
    }

    private func confirmContent(expired: Bool, remaining: TimeInterval) -> some View {
        VStack(spacing: Spacing.lg) {
            if model.usesQuote {
                QuoteCountdownBar(remaining: remaining, total: model.quote?.ttl ?? 20)
            }
            CryptoConfirmCard(
                title: model.orderType == .market ? "Маркет-ордер по live-курсу" : "Лимитный ордер",
                payValue: payNumber, paySymbol: payUnit,
                getValue: getNumber, getSymbol: getUnit,
                rows: confirmRows
            )
            PrimaryButton(title: expired ? "Обновить курс" : model.confirmVerb,
                          icon: expired ? nil : "faceid",
                          isLoading: model.authorizing) {
                Task { await model.authorize() }
            }
            SecondaryButton(title: "Назад") { model.backToForm() }
        }
    }

    private var buying: Bool { model.side == .buy }
    private var payNumber: String { buying ? MoneyFormat.number(model.rubAmount.rounded(), maxFractionDigits: 0) : CryptoFormat.qty(model.assetAmount) }
    private var payUnit: String { buying ? "₽" : model.symbol }
    private var getNumber: String { buying ? CryptoFormat.qty(model.assetAmount) : MoneyFormat.number(model.rubAmount.rounded(), maxFractionDigits: 0) }
    private var getUnit: String { buying ? model.symbol : "₽" }

    private var confirmRows: [CryptoConfirmRow] {
        var rows: [CryptoConfirmRow] = [CryptoConfirmRow(label: "Тип", value: model.orderType == .market ? "Маркет" : "Лимит")]
        if model.orderType == .market {
            rows.append(CryptoConfirmRow(label: "Курс (live)", value: CryptoFormat.rub(model.execRate)))
            rows.append(CryptoConfirmRow(label: "Спред (\(model.spreadTier.label))", value: CryptoSpread.label(for: model.spreadTier), accent: true))
        } else {
            rows.append(CryptoConfirmRow(label: "Цена", value: CryptoFormat.rub(model.execRate), accent: true))
        }
        rows.append(CryptoConfirmRow(label: "Объём", value: CryptoFormat.qty(model.assetAmount, symbol: model.symbol)))
        rows.append(CryptoConfirmRow(label: "Сумма", value: CryptoFormat.rub(model.rubAmount), emphasized: true))
        if model.tpEnabled, CryptoFormat.parse(model.tpPriceText) > 0 {
            rows.append(CryptoConfirmRow(label: "Тейк-профит", value: CryptoFormat.rub(CryptoFormat.parse(model.tpPriceText))))
        }
        if model.slEnabled, CryptoFormat.parse(model.slPriceText) > 0 {
            rows.append(CryptoConfirmRow(label: "Стоп-лосс", value: CryptoFormat.rub(CryptoFormat.parse(model.slPriceText))))
        }
        if model.orderType == .limit {
            rows.append(CryptoConfirmRow(label: "Время действия", value: model.goodTillCanceled ? "GTC, до отмены" : "На день"))
            if model.postOnly { rows.append(CryptoConfirmRow(label: "Post-Only", value: "Да")) }
        }
        return rows
    }

    // MARK: Status

    private var statusOverlay: some View {
        CryptoStatusView(
            outcome: model.outcome ?? .processing,
            successTitle: successTitle, successDetail: successDetail,
            amount: model.assetAmount, currency: model.symbol,
            onRetry: { model.retry() }, onClose: { dismiss() }
        )
        .background(theme.background.ignoresSafeArea())
    }
    private var successTitle: String {
        if model.placedLimit { return "Ордер размещён" }
        return buying ? "Куплено" : "Продано"
    }
    private var successDetail: String {
        if model.placedLimit { return "Лимитный ордер на \(CryptoFormat.qty(model.assetAmount, symbol: model.symbol)) по \(CryptoFormat.rub(model.execRate)) в книге заявок." }
        return buying ? "Зачислено \(CryptoFormat.qty(model.assetAmount, symbol: model.symbol))." : "Зачислено \(CryptoFormat.rub(model.rubAmount))."
    }
}

#Preview {
    NavigationStack {
        TradeOrderView(symbol: "BTC", side: .buy)
            .environment(Router())
            .environment(AppSession.mockAuthenticated())
            .environment(\.apiClient, MockAPIClient())
            .environment(\.theme, .default)
    }
}
