import SwiftUI

/// Конвертация крипто↔₽ (мгновенно) и крипто↔стейблкоин 1:1 (§9.6). Amount → preview (курс по
/// live-цене, спред зависит от тира) → биометрия → исполнение (симуляция). The confirm step runs a
/// live TTL countdown that forces a re-quote on a stale rate (§10.8). Gated for неквал by the risk
/// test + 300к лимит (crypto only).
struct ConvertView: View {
    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var model: ConvertFlowModel
    @State private var store = CryptoStore.shared
    @State private var showRiskTest = false

    init(asset: String?) { _model = State(initialValue: ConvertFlowModel(asset: asset)) }

    private var investorStatus: InvestorStatus { session.currentUser?.investorStatus ?? .unqualified }
    private var directions: [ConvertFlowModel.Direction] {
        model.canSwap ? [.sell, .buy, .swap] : [.sell, .buy]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                switch model.step {
                case .amount:  amountStep
                case .confirm: confirmStep
                case .status:  EmptyView()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Конвертация")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.step == .status { statusOverlay } }
        .task { await model.load(api: api, session: session) }
        .onAppear { if store.requiresRiskTest(investorStatus: investorStatus) { showRiskTest = true } }
        .bottomSheet(isPresented: $showRiskTest, detents: [.large]) {
            RiskTestSheet(onPass: { store.passRiskTest(); showRiskTest = false },
                          onCancel: { showRiskTest = false; dismiss() })
        }
    }

    // MARK: Amount

    private var amountStep: some View {
        VStack(spacing: Spacing.lg) {
            assetMenu
            Picker("", selection: $model.direction) {
                ForEach(directions) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            AmountEntry(
                text: $model.amountText,
                symbol: model.entrySymbol,
                secondary: secondaryLine,
                secondaryIsWarning: model.insufficientFunds
            )

            if model.direction != .swap {
                Button { model.inputInAsset.toggle() } label: {
                    Label("Ввод в \(model.inputInAsset ? "₽" : model.asset)", systemImage: "arrow.up.arrow.down")
                        .font(BrandFont.caption.weight(.medium))
                        .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                }
                .buttonStyle(.plain)
            }

            gateView

            if model.spreadTier == .standard {
                UpsellCard(title: "Pro: спред ниже",
                           message: "На Pro и Infinite спред на обмене меньше — конвертация выгоднее.",
                           recommendedTier: .pro)
            }

            PrimaryButton(title: "Продолжить") { model.goToConfirm() }
                .disabled(!model.canProceed)
        }
    }

    private var secondaryLine: String {
        if model.insufficientFunds { return "Недостаточно средств · доступно \(CryptoFormat.qty(model.balance, symbol: model.asset))" }
        return "Получите ≈ \(model.getText)"
    }

    private var assetMenu: some View {
        Menu {
            ForEach(CryptoCatalog.tradable) { asset in
                Button(asset.symbol) { model.setAsset(asset.symbol) }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                AssetGlyph(symbol: model.asset, size: 32)
                Text(model.asset).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(theme.textSecondary)
                Spacer()
                Text(CryptoFormat.rub(model.midPrice)).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
    }

    @ViewBuilder private var gateView: some View {
        if case .investorLimit(let remaining) = model.gate {
            LimitGateCard(kind: .investor(remaining: remaining),
                          onAdjust: { model.amountText = "" },
                          onTakeInvestorTest: { router.push(CryptoRoute.investorStatus) })
        }
    }

    // MARK: Confirm (with live TTL)

    private var confirmStep: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let expired = model.quoteExpired(at: context.date)
            VStack(spacing: Spacing.lg) {
                QuoteCountdownBar(remaining: model.quoteRemaining(at: context.date), total: model.quote?.ttl ?? 20)

                CryptoConfirmCard(
                    title: titleForConfirm,
                    payValue: payNumber, paySymbol: payUnit,
                    getValue: getNumber, getSymbol: model.getSymbol,
                    rows: confirmRows
                )

                PrimaryButton(title: expired ? "Обновить курс" : "Подтвердить · Face ID",
                              icon: expired ? "arrow.clockwise" : "faceid",
                              isLoading: model.authorizing) {
                    Task { await model.authorize() }
                }
                SecondaryButton(title: "Назад") { model.backToAmount() }
            }
        }
    }

    private var titleForConfirm: String {
        switch model.direction {
        case .sell: return "Обмен \(model.asset) → ₽ по live-курсу"
        case .buy:  return "Покупка \(model.asset) по live-курсу"
        case .swap: return "Обмен стейблкоинов 1:1"
        }
    }
    private var payNumber: String { numberOnly(model.payText) }
    private var payUnit: String { model.direction == .buy ? "₽" : model.asset }
    private var getNumber: String { numberOnly(model.getText) }

    private var confirmRows: [CryptoConfirmRow] {
        var rows: [CryptoConfirmRow] = []
        if model.direction == .swap {
            rows.append(CryptoConfirmRow(label: "Курс", value: "1 : 1", accent: true))
        } else {
            rows.append(CryptoConfirmRow(label: "Курс (live)", value: CryptoFormat.rub(model.effectiveRate)))
            rows.append(CryptoConfirmRow(label: "Спред (\(model.spreadTier.label))",
                                         value: CryptoSpread.label(for: model.spreadTier), accent: true))
        }
        rows.append(CryptoConfirmRow(label: "Комиссия", value: "Без комиссии"))
        rows.append(CryptoConfirmRow(label: "Итог", value: model.getText, emphasized: true))
        return rows
    }

    // MARK: Status

    private var statusOverlay: some View {
        CryptoStatusView(
            outcome: model.outcome ?? .processing,
            successTitle: model.direction == .swap ? "Обмен выполнен" : "Конвертация выполнена",
            successDetail: "Зачислено \(model.getText). Исполнено по live-курсу.",
            amount: model.assetAmount, currency: model.asset,
            onRetry: { model.retry() },
            onClose: { dismiss() }
        )
        .background(theme.background.ignoresSafeArea())
    }

    private func numberOnly(_ s: String) -> String {
        s.replacingOccurrences(of: " ₽", with: "")
         .replacingOccurrences(of: " \(model.asset)", with: "")
         .replacingOccurrences(of: " \(model.counterStable)", with: "")
    }
}

#Preview {
    NavigationStack {
        ConvertView(asset: "BTC")
            .environment(Router())
            .environment(AppSession.mockAuthenticated())
            .environment(\.apiClient, MockAPIClient())
            .environment(\.theme, .default)
    }
}
