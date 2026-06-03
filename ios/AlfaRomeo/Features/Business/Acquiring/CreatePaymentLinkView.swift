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

                SurfaceCard {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: model.kind.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 36, height: 36)
                            .background(
                                theme.accent.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            )
                        Text(model.kind.hint)
                            .font(BrandFont.caption)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: Spacing.md)

                PrimaryButton(title: model.kind.actionTitle, icon: model.kind.systemImage) {
                    if let link = model.generate(store: store) {
                        router.push(AcquiringRoute.linkResult(link))
                    }
                }
                .disabled(!model.canGenerate)
            }
            .padding(Spacing.lg)
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
