import SwiftUI

/// One approval (§11.8): the payment, the 2-of-N signature progress, and the action to **add a
/// signature with biometrics** as the next eligible signer (владелец / бухгалтер). When the required
/// count is reached the payment executes (simulation) and the screen flips to a success state.
struct ApprovalDetailView: View {
    let approvalId: String

    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = TeamStore.shared

    @State private var signing = false
    @State private var executing = false
    @State private var signError: SignError?
    @State private var pop = false

    private let bio = BiometricAuthenticator.available()
    private var item: ApprovalItem? { store.approvalItem(id: approvalId) }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    paymentCard(item)
                    signatureCard(item)
                    actionArea(item)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Заявка не найдена").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.lg)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Подпись платежа")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.smooth, value: item?.signedCount)
        .animation(reduceMotion ? nil : Motion.smooth, value: executing)
    }

    // MARK: Payment

    private func paymentCard(_ item: ApprovalItem) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.draft.supplierName).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text(item.draft.supplierDetail).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                AmountText(amount: item.draft.amount, currency: "₽", size: 34)
                SurfaceCard(padding: Spacing.sm, elevated: true) {
                    VStack(spacing: 0) {
                        row("Назначение", item.draft.purpose)
                        Divider().overlay(theme.border)
                        row("Списание", item.draft.sourceTitle)
                        Divider().overlay(theme.border)
                        row("Инициатор", item.draft.initiatorName)
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Signatures

    private func signatureCard(_ item: ApprovalItem) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Подписи").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(item.progressLabel).font(BrandFont.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary).monospacedDigit()
                }
                SignatureProgressView(slots: item.slots, rejected: item.isRejected)
            }
        }
    }

    // MARK: Action

    @ViewBuilder private func actionArea(_ item: ApprovalItem) -> some View {
        if executing {
            processingState
        } else if item.isComplete {
            resultState(success: true)
        } else if item.isRejected {
            resultState(success: false)
        } else {
            pendingActions(item)
        }
    }

    @ViewBuilder private func pendingActions(_ item: ApprovalItem) -> some View {
        if let signer = store.nextEligibleSigner(approvalId: approvalId) {
            VStack(spacing: Spacing.sm) {
                if let signError {
                    Text(signError.message)
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.isDark ? theme.danger : BrandColors.dangerInkLight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                PrimaryButton(title: "Подписать как \(firstName(signer.name)) · \(bio.label)",
                              icon: bio.systemImage, isLoading: signing) {
                    Task { await sign(as: signer) }
                }
                Text("Подпись \(signer.roleLabel.lowercased()) · подтверждение биометрией (§11.8)")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Button(role: .destructive) {
                    store.reject(approvalId: approvalId, byUserId: signer.id)
                } label: {
                    Text("Отклонить платёж")
                        .font(BrandFont.callout.weight(.medium))
                        .foregroundStyle(theme.isDark ? theme.danger : BrandColors.dangerInkLight)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        } else {
            SurfaceCard {
                Label("Нет доступного второго подписанта с правом подписи.", systemImage: "exclamationmark.triangle")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var processingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().controlSize(.large).tint(theme.accent)
            Text("Исполняем платёж…").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
    }

    private func resultState(success: Bool) -> some View {
        let tint = success ? (theme.isDark ? theme.success : BrandColors.successInkLight)
                           : (theme.isDark ? theme.danger : BrandColors.dangerInkLight)
        return VStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.14)).frame(width: 96, height: 96)
                Image(systemName: success ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 40, weight: .bold)).foregroundStyle(tint)
                    .scaleEffect(pop ? 1 : 0.5).opacity(pop ? 1 : 0)
            }
            Text(success ? "Платёж исполнен" : "Платёж отклонён")
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text(success ? "Все подписи собраны. Исполнение — симуляция (§14)."
                         : "Заявка отклонена. Средства не списаны.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Готово", icon: "checkmark") { router.popToRoot() }
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.sm)
        .onAppear { withAnimation(reduceMotion ? nil : Motion.bouncy.delay(0.05)) { pop = true } }
    }

    // MARK: Sign

    private func sign(as signer: TeamMember) async {
        signError = nil
        signing = true
        let ok = await BiometricAuthenticator.authenticate(
            reason: "Подписать платёж поставщику \(SupplierPaymentModel.rub(item?.draft.amount ?? 0))")
        signing = false
        guard ok else { signError = .biometricFailed; return }

        switch store.sign(approvalId: approvalId, asUserId: signer.id) {
        case .failure(let err):
            signError = err
        case .success(let updated):
            if updated.isComplete {
                executing = true
                try? await Task.sleep(for: .seconds(1.2))
                executing = false
            }
        }
    }

    private func firstName(_ s: String) -> String { s.split(separator: " ").first.map(String.init) ?? s }
}
