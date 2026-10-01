import SwiftUI

struct CreatePaymentLinkView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @State private var store = AcquiringStore.shared
    @State private var model: CreateLinkModel

    init(kind: PaymentLink.Kind) {
        _model = State(initialValue: CreateLinkModel(kind: kind))
    }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("Тип", selection: $model.kind) {
                    ForEach(PaymentLink.Kind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                AcquiringAmountField(title: "Сумма", text: $model.amountText)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Назначение")
                            .font(BrandFont.caption)
                            .foregroundStyle(theme.textSecondary)
                        TextField("За товар/услугу", text: $model.purpose)
                            .font(BrandFont.bodyM)
                            .foregroundStyle(theme.textPrimary)
                    }
                }

                Text(model.kind.hint)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.md)

                Spacer(minLength: Spacing.md)

                PrimaryButton(title: model.kind.actionTitle) {
                    if let link = model.generate(store: store) {
                        router.push(AcquiringRoute.linkResult(link))
                    }
                }
                .disabled(!model.canGenerate)
            }
            .padding(Spacing.screen)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новый платёж")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreatePaymentLinkView_PreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            CreatePaymentLinkView(kind: .qr)
                .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview {
    CreatePaymentLinkView_PreviewHost()
}
