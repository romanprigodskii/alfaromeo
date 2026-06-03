import SwiftUI

/// Оплата связи (§7.2 «Оплата связи» с любого счёта, вкл. крипту; §7.1 роуминг криптой).
///
/// One screen for every ``MobilePaymentPurpose`` (пополнение / роуминг / тариф): set a сумма via quick
/// chips, pick a pay-from ``PaymentSource`` (fiat / цифр.₽ / crypto), and record the payment in the
/// shared ``MobileStore`` — so the hub's «Платежи связи» history reflects it live. For роуминг (§7.1)
/// the source list leads with crypto (`purpose.prefersCrypto`). Mirrors `QuickMoveSheet`'s chips +
/// success idiom; pushed onto the hub's `NavigationStack` via `MobileRoute.payment`.
struct MobilePaymentView: View {
    let purpose: MobilePaymentPurpose

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared
    @State private var amount: Double = 0
    @State private var selectedSourceId: String?
    @State private var done = false

    private var profileId: String { session.activeProfile?.id ?? "" }

    private let quickAmounts: [Double] = [200, 500, 1_000, 2_000]

    private var sources: [PaymentSource] { store.paymentSources(cryptoFirst: purpose.prefersCrypto) }
    private var selectedSource: PaymentSource? {
        sources.first { $0.id == selectedSourceId } ?? sources.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if done {
                    successView
                } else {
                    composer
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(purpose.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: amount)
        .task {
            await store.load(api: api, profileId: profileId)
            if selectedSourceId == nil { selectedSourceId = sources.first?.id }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header

            AmountText(amount: amount, size: 34)

            chips

            sourcesCard

            PrimaryButton(title: purpose.title, icon: "checkmark") {
                if let s = selectedSource {
                    store.recordPayment(purpose: purpose, amount: amount, source: s)
                }
                withAnimation(reduceMotion ? nil : Motion.smooth) { done = true }
            }
            .disabled(amount <= 0 || selectedSource == nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(purpose.title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text(purpose.prompt).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(quickAmounts, id: \.self) { value in
                    Button { withAnimation(reduceMotion ? nil : Motion.snappy) { amount += value } } label: {
                        Text("+\(Int(value)) ₽").font(BrandFont.callout.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                            .foregroundStyle(theme.textPrimary)
                            .background(theme.elevated, in: Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            SecondaryButton(title: "Сброс", icon: "arrow.counterclockwise") {
                withAnimation(reduceMotion ? nil : Motion.snappy) { amount = 0 }
            }
        }
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Счёт списания").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { i, source in
                        PaymentSourceRow(
                            source: source,
                            isSelected: source.id == selectedSource?.id
                        ) { selectedSourceId = source.id }
                        if i < sources.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
            Text("Оплата с любого счёта, включая крипту (§7.1).")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundStyle(theme.success)
            Text(purpose.title + " выполнена")
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            AmountText(amount: -amount, size: 24, showsSign: true, colorBySign: true)
            if let title = selectedSource?.title {
                Text(title).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
            PrimaryButton(title: "Готово") { dismiss() }
                .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }
}

// MARK: - Preview

private struct MobilePaymentPreviewHost: View {
    let session: AppSession
    let purpose: MobilePaymentPurpose
    var body: some View {
        NavigationStack {
            MobilePaymentView(purpose: purpose)
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Оплата связи") {
    MobilePaymentPreviewHost(session: .mockAuthenticated(), purpose: .topUp)
}

#Preview("Оплата роуминга (крипта)") {
    MobilePaymentPreviewHost(session: .mockAuthenticated(), purpose: .roaming)
}
