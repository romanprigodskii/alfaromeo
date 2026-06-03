import SwiftUI

/// §8.3 — демо-сценарий приёма оплаты: сумма → способ → (крипта: авто-конвертация
/// в ₽ по live-курсу) → биометрия → статус + чек. Pushed destination.
struct AcceptPaymentView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session

    @State private var model = AcceptPaymentModel()
    @State private var store = AcquiringStore.shared
    @State private var prices = LivePriceService.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        @Bindable var model = model

        Group {
            switch model.step {
            case .input:
                inputView
            case .status:
                statusView
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Приём оплаты")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prices.start() }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Input

    private var inputView: some View {
        @Bindable var model = model

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AcquiringAmountField(title: "Сумма к оплате", text: $model.priceText)

                Text("Способ оплаты")
                    .font(BrandFont.headline)
                    .foregroundStyle(theme.textPrimary)

                VStack(spacing: Spacing.sm) {
                    ForEach(PaymentMethod.allCases) { method in
                        PaymentMethodRow(
                            method: method,
                            detail: method.feeLabel,
                            isSelected: model.method == method
                        ) {
                            withAnimation(Motion.snappy) { model.method = method }
                        }
                    }
                }

                if model.method == .crypto {
                    Picker("", selection: $model.cryptoAsset) {
                        ForEach(model.stableAssets, id: \.self) { asset in
                            Text(asset).tag(asset)
                        }
                    }
                    .pickerStyle(.segmented)

                    CryptoConversionCard(
                        asset: model.cryptoAsset,
                        stableAmount: model.stableAmount,
                        rate: model.liveRate,
                        creditedRub: model.creditedRub,
                        isLive: model.pricesAreLive
                    )
                } else if model.canAccept {
                    SurfaceCard(padding: Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Зачислится")
                                    .font(BrandFont.caption)
                                    .foregroundStyle(theme.textSecondary)
                                Text("Комиссия \(model.method.feeLabel) · \(CryptoFormat.rub(model.feeRub))")
                                    .font(BrandFont.micro)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            AmountText(amount: model.creditedRub, size: 22)
                        }
                    }
                }

                PrimaryButton(
                    title: model.canAccept ? "Принять \(CryptoFormat.rub(model.creditedRub))" : "Принять оплату",
                    icon: "checkmark.shield.fill",
                    isLoading: model.authorizing
                ) {
                    Task { await model.authorizeAndSettle(store: store) }
                }
                .disabled(!model.canAccept)
            }
            .padding(Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Status

    private var statusView: some View {
        Group {
            if let outcome = model.outcome {
                AcquiringStatusView(
                    outcome: outcome,
                    onClose: { router.pop() },
                    onRetry: { model.reset() }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Preview

private struct AcceptPaymentView_PreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            AcceptPaymentView()
                .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview {
    AcceptPaymentView_PreviewHost()
}
