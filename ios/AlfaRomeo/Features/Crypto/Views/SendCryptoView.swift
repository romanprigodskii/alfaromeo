import SwiftUI

/// Отправить крипту (§9.6): контакту (по телефону, как Revolut) / на адрес / по QR, с выбором сети и
/// превью комиссии. Крипто-переводы — привилегия Pro+ (`cryptoTransfers`); на Base показывается мягкий
/// апселл. Edge cases: «сеть перегружена» (ERC-20) и «недостаточно средств» (§10.8).
struct SendCryptoView: View {
    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var model: SendCryptoModel
    @State private var store = CryptoStore.shared
    @State private var canSend = true
    @State private var showRiskTest = false
    @State private var showScanner = false

    init(asset: String?) {
        _model = State(initialValue: SendCryptoModel(asset: asset ?? "BTC"))
    }

    private var investorStatus: InvestorStatus { session.currentUser?.investorStatus ?? .unqualified }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !canSend {
                    upsell
                } else {
                    switch model.step {
                    case .form:    formStep
                    case .confirm: confirmStep
                    case .status:  EmptyView()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Отправить \(model.asset)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.step == .status { statusOverlay } }
        .task {
            model.load(session: session)
            let profileId = session.activeProfile?.id ?? ""
            let fallback = (try? await api.subscription(profileId: profileId))?.tier ?? .base
            let tier = session.currentTier(for: profileId, fallback: fallback)
            canSend = Entitlements.make(for: tier).cryptoTransfers
            // Gate the risk test only after the tier (canSend) is known — avoids a flash/false gate.
            if canSend && store.requiresRiskTest(investorStatus: investorStatus) { showRiskTest = true }
        }
        .bottomSheet(isPresented: $showRiskTest, detents: [.large]) {
            RiskTestSheet(onPass: { store.passRiskTest(); showRiskTest = false },
                          onCancel: { showRiskTest = false; dismiss() })
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView(asset: model.asset) { address in
                withAnimation { model.applyScannedAddress(address) }
            }
        }
    }

    private var upsell: some View {
        UpsellCard(title: "Крипто-переводы на Pro",
                   message: "Отправка крипты контактам и на внешние адреса доступна с тарифа Pro. Конвертация и торговля работают на всех тарифах.",
                   recommendedTier: .pro)
    }

    // MARK: Form

    private var formStep: some View {
        VStack(spacing: Spacing.lg) {
            balanceHeader
            Picker("", selection: $model.mode) {
                ForEach(SendCryptoModel.RecipientMode.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)

            recipientInput

            AmountEntry(text: $model.amountText, symbol: model.asset,
                        secondary: model.insufficientFunds
                            ? "Недостаточно средств · доступно \(CryptoFormat.qty(model.balance, symbol: model.asset))"
                            : "≈ \(CryptoFormat.rub(model.rubAmount))",
                        secondaryIsWarning: model.insufficientFunds)

            NetworkFeePicker(networks: model.networks, selected: $model.network)

            gateView

            PrimaryButton(title: "Продолжить") { model.goToConfirm() }
                .disabled(!model.canProceed)
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: Spacing.md) {
            AssetGlyph(symbol: model.asset, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Баланс").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                Text(CryptoFormat.qty(model.balance, symbol: model.asset)).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            }
            Spacer()
        }
    }

    @ViewBuilder private var recipientInput: some View {
        switch model.mode {
        case .contact:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(PaymentsMockData.contacts) { contact in
                        contactChip(contact)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        case .address:
            TextField("Адрес кошелька", text: $model.addressText)
                .font(BrandFont.mono(15))
                .foregroundStyle(theme.textPrimary)
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
        case .qr:
            Button { showScanner = true } label: {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: model.qrScanned ? "checkmark.circle.fill" : "qrcode.viewfinder")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(model.qrScanned ? theme.success : (theme.accentCrypto.first ?? theme.accent))
                    Text(model.qrScanned ? "QR отсканирован" : "Сканировать QR-адрес")
                        .font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    if model.qrScanned, let addr = model.scannedAddress {
                        Text(addr)
                            .font(BrandFont.mono(12)).foregroundStyle(theme.textSecondary)
                            .lineLimit(1).truncationMode(.middle)
                            .padding(.horizontal, Spacing.md)
                    } else {
                        Text("Откроется камера · на симуляторе — фолбэк")
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(model.qrScanned ? theme.success : theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func contactChip(_ contact: PaymentContact) -> some View {
        let selected = model.selectedContact?.id == contact.id
        return Button { model.selectedContact = contact } label: {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle().fill(selected ? AnyShapeStyle(theme.cryptoGradient) : AnyShapeStyle(theme.elevated))
                        .frame(width: 52, height: 52)
                    Text(contact.initials).font(BrandFont.headline).foregroundStyle(selected ? .white : theme.textPrimary)
                }
                Text(contact.name.split(separator: " ").first.map(String.init) ?? contact.name)
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder private var gateView: some View {
        if case .investorLimit(let remaining) = model.gate {
            LimitGateCard(kind: .investor(remaining: remaining),
                          onAdjust: { model.amountText = "" },
                          onTakeInvestorTest: { router.push(CryptoRoute.investorStatus) })
        }
    }

    // MARK: Confirm (reuses the Payments ConfirmSummaryCard)

    private var confirmStep: some View {
        VStack(spacing: Spacing.lg) {
            ConfirmSummaryCard(
                recipient: Recipient(name: model.recipientLabel, detail: model.recipientDetail,
                                     icon: "bitcoinsign.circle.fill", bank: model.network?.name),
                amount: model.assetAmount, amountSymbol: model.asset,
                fee: model.feeRub, feeLabel: "Комиссия сети",
                rubEquivalent: model.rubAmount,
                sourceTitle: "Крипто-кошелёк", sourceSubtitle: "\(model.asset) · \(CryptoCatalog.chainLabel(model.asset))",
                totalText: nil
            )
            if model.network?.congested == true {
                Text("Выбрана перегруженная сеть — возможна задержка и высокая комиссия.")
                    .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PrimaryButton(title: "Отправить · Face ID", icon: "faceid", isLoading: model.authorizing) {
                Task { await model.authorize() }
            }
            SecondaryButton(title: "Назад") { model.backToForm() }
        }
    }

    private var statusOverlay: some View {
        CryptoStatusView(
            outcome: model.outcome ?? .processing,
            successTitle: "Отправлено",
            successDetail: "\(model.recipientLabel) получит \(CryptoFormat.qty(model.assetAmount, symbol: model.asset)).",
            amount: model.assetAmount, currency: model.asset,
            onRetry: { model.retry() }, onClose: { dismiss() }
        )
        .background(theme.background.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        SendCryptoView(asset: "ETH")
            .environment(Router())
            .environment(AppSession.mockAuthenticated())
            .environment(\.apiClient, MockAPIClient())
            .environment(\.theme, .default)
    }
}
