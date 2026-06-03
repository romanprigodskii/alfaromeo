import SwiftUI

/// Мгновенное подключение eSIM (§7.1 «Мгновенный eSIM: активация по QR; новый номер или перенос (MNP)»).
///
/// Реалистичный STUB-визард в четыре шага: выбор способа → детали → провижининг → готово. Способы
/// (``ESIMMethod``) и шаги провижининга — из модуля; провижининг анимируется по шагам, после чего
/// ``MobileStore/provisionESIM(method:profileId:portedNumber:)`` создаёт/обновляет план (QR и новый
/// номер выдают свежий MSISDN, перенос сохраняет номер по MNP), и план live-обновляется в хабе.
struct ESIMConnectView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    private enum Step { case method, details, provisioning, done }

    @State private var step: Step = .method
    @State private var method: ESIMMethod = .qr
    @State private var portedNumber = ""
    @State private var donor: ESIMDonor = .mts
    @State private var chosenNumber = "+7 999 700-15-77"
    @State private var provisioningStep = 0
    @State private var didProvision = false

    private var profileId: String { session.activeProfile?.id ?? "" }

    /// Demo-каталог «красивых» номеров для способа «Новый номер».
    private let candidateNumbers = [
        "+7 999 700-15-77",
        "+7 999 100-20-30",
        "+7 999 777-88-99",
        "+7 999 500-50-50",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                switch step {
                case .method:       methodStep
                case .details:      detailsStep
                case .provisioning: provisioningStepView
                case .done:         doneStep
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Подключение eSIM")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.smooth, value: step)
        .animation(reduceMotion ? nil : Motion.snappy, value: provisioningStep)
        .task { await store.load(api: api, profileId: profileId) }
    }

    // MARK: - Шаг 1 · Способ

    private var methodStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Как подключить eSIM").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("Мгновенно — по QR, с новым номером или переносом своего (MNP). Тариф в связке с вашим классом (§7.1).")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.md) {
                ForEach(ESIMMethod.allCases) { m in
                    ESIMMethodCard(method: m, isSelected: method == m) {
                        withAnimation(reduceMotion ? nil : Motion.snappy) { method = m }
                    }
                }
            }

            PrimaryButton(title: "Продолжить", icon: "arrow.right") {
                withAnimation(reduceMotion ? nil : Motion.smooth) { step = .details }
            }
        }
    }

    // MARK: - Шаг 2 · Детали

    @ViewBuilder
    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(method.title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text(method.subtitle).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch method {
            case .qr:        qrDetails
            case .newNumber: newNumberDetails
            case .transfer:  transferDetails
            }

            PrimaryButton(title: "Подключить eSIM", icon: "simcard") {
                startProvisioning()
            }
            .disabled(method == .transfer && portedNumber.count < 10)
        }
    }

    private var qrDetails: some View {
        SurfaceCard {
            VStack(spacing: Spacing.md) {
                Image(systemName: "qrcode")
                    .font(.system(size: 140))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                Text("Сканируйте QR в приложении оператора (демо)")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var newNumberDetails: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                ForEach(Array(candidateNumbers.enumerated()), id: \.element) { i, number in
                    Button {
                        withAnimation(reduceMotion ? nil : Motion.snappy) { chosenNumber = number }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Text(number)
                                .font(BrandFont.mono(17, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer(minLength: Spacing.sm)
                            Image(systemName: chosenNumber == number ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(chosenNumber == number ? theme.accent : theme.border)
                        }
                        .padding(.vertical, Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < candidateNumbers.count - 1 { Divider().overlay(theme.border) }
                }
            }
        }
    }

    private var transferDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Ваш номер").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                TextField("Ваш номер", text: $portedNumber)
                    .keyboardType(.phonePad)
                    .font(BrandFont.mono(20, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .padding(Spacing.md)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Текущий оператор").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                Menu {
                    ForEach(ESIMDonor.allCases) { d in
                        Button(d.rawValue) { donor = d }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.accent)
                        Text(donor.rawValue).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textSecondary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
            }

            Label("Номер сохранится (MNP)", systemImage: "checkmark.shield.fill")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Шаг 3 · Провижининг

    private var provisioningStepView: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Подключаем eSIM").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("Это займёт несколько секунд (демо).")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(Array(method.provisioningSteps.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: Spacing.md) {
                            stepIcon(for: index)
                                .frame(width: 24, height: 24)
                            Text(title)
                                .font(BrandFont.bodyM)
                                .foregroundStyle(index <= provisioningStep ? theme.textPrimary : theme.textSecondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func stepIcon(for index: Int) -> some View {
        if index < provisioningStep {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20)).foregroundStyle(theme.success)
        } else if index == provisioningStep {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 20)).foregroundStyle(theme.border)
        }
    }

    // MARK: - Шаг 4 · Готово

    private var doneStep: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(theme.success)

            Text("eSIM активирована")
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)

            VStack(spacing: Spacing.xs) {
                Text("Ваш номер").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                Text(store.plan?.msisdn ?? chosenNumber)
                    .font(BrandFont.mono(22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))

            Spacer(minLength: Spacing.xl)

            PrimaryButton(title: "Готово") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: provisionIfNeeded)
    }

    // MARK: - Flow

    private func startProvisioning() {
        provisioningStep = 0
        withAnimation(reduceMotion ? nil : Motion.smooth) { step = .provisioning }

        let steps = method.provisioningSteps
        let delay: UInt64 = reduceMotion ? 250_000_000 : 700_000_000
        Task {
            for index in steps.indices {
                try? await Task.sleep(nanoseconds: delay)
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { provisioningStep = index + 1 }
                }
            }
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                withAnimation(reduceMotion ? nil : Motion.smooth) { step = .done }
            }
        }
    }

    private func provisionIfNeeded() {
        guard !didProvision else { return }
        didProvision = true
        store.provisionESIM(method: method, profileId: profileId,
                            portedNumber: method == .transfer ? portedNumber : nil)
    }
}

// MARK: - Preview

private struct ESIMConnectPreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            ESIMConnectView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Подключение eSIM") {
    ESIMConnectPreviewHost(session: .mockAuthenticated())
}
