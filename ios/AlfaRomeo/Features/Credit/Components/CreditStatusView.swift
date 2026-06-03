import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Animated credit-application outcome (§10.5) — reuses the §9.2/§10.6 medallion language: обработка →
/// одобрено / отказ + причина. On a decline it also surfaces «что улучшить» and a one-tap «Спросить у
/// AI» entry (§10.9). A single medallion morphs between states; honors Reduce Motion.
struct CreditStatusView: View {
    let outcome: CreditOutcome
    var productKind: CreditKind
    var amount: Double
    var caption: String            // напр. «Платёж 24 600 ₽/мес · 36 мес»
    var onDone: () -> Void
    var onRetry: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell: ShellState?   // optional → Previews/harness need not inject

    @State private var spin = false
    @State private var pop = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.xl)

            medallion

            VStack(spacing: Spacing.sm) {
                Text(headline).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)
            }

            if case .success = outcome {
                VStack(spacing: Spacing.xxs) {
                    AmountText(amount: amount, size: 26)
                    Text(caption).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                .padding(.top, Spacing.xs)
            }

            if case .declined(let reason) = outcome {
                improvementCard(reason.improvement)
            }

            Spacer(minLength: Spacing.lg)

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
        .background(theme.background.ignoresSafeArea())
        .onAppear { startAnimations() }
        .onChange(of: outcomeKey) { _, _ in startAnimations() }
        .animation(reduceMotion ? nil : Motion.smooth, value: outcomeKey)
    }

    // MARK: Medallion

    private var medallion: some View {
        ZStack {
            Circle().fill(tint.opacity(0.14)).frame(width: 132, height: 132)
                .scaleEffect(isProcessing && !reduceMotion ? (spin ? 1.06 : 0.94) : 1)
                .animation(isProcessing && !reduceMotion
                           ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : nil, value: spin)

            if isProcessing {
                Circle().trim(from: 0, to: 0.72)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: spin)
            } else {
                Circle().stroke(tint, lineWidth: 4).frame(width: 104, height: 104)
            }

            Image(systemName: symbol)
                .font(.system(size: 46, weight: .bold)).foregroundStyle(tint)
                .scaleEffect(pop ? 1 : 0.4).opacity(pop ? 1 : 0)
        }
        .accessibilityLabel(headline)
    }

    private func improvementCard(_ text: String) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill").foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Что улучшить").font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                    Text(text).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder private var actions: some View {
        switch outcome {
        case .processing:
            EmptyView()
        case .success:
            PrimaryButton(title: "Готово", icon: "checkmark") { onDone() }
        case .declined(let reason):
            VStack(spacing: Spacing.sm) {
                // A canceled biometric retries the prompt → biometric glyph; other declines reload.
                // The glyph is derived from the device's actual biometry (not a hardcoded "faceid").
                PrimaryButton(title: "Повторить",
                              icon: reason == .canceled ? BiometricAuthenticator.available().systemImage : "arrow.clockwise") { onRetry() }
                SecondaryButton(title: "Спросить у AI", icon: "sparkles") {
                    shell?.showCopilot(.declined(reason: reason.copilotReason))
                }
                SecondaryButton(title: "Закрыть") { onDone() }
            }
        }
    }

    // MARK: Derived

    private var isProcessing: Bool { if case .processing = outcome { return true }; return false }

    private var tint: Color {
        switch outcome {
        case .processing: return theme.accent
        case .success:    return theme.success
        case .declined:   return theme.danger
        }
    }

    private var symbol: String {
        switch outcome {
        case .processing: return "arrow.triangle.2.circlepath"
        case .success:    return productKind == .card ? "creditcard.fill" : "checkmark"
        case .declined(let reason): return reason.systemImage
        }
    }

    private var headline: String {
        switch outcome {
        case .processing: return "Рассматриваем заявку"
        case .success:
            switch productKind {
            case .card:        return "Карта одобрена"
            case .installment: return "Рассрочка оформлена"
            case .cash:        return "Кредит одобрен"
            }
        case .declined(let reason): return reason.title
        }
    }

    private var subtitle: String {
        switch outcome {
        case .processing: return "Проверяем данные и подтверждаем условия…"
        case .success:    return "Готово. Деньги поступят на ваш счёт в течение минуты."
        case .declined(let reason): return reason.message
        }
    }

    private var outcomeKey: String {
        switch outcome {
        case .processing: return "p"
        case .success:    return "s"
        case .declined(let r): return "d-\(r)"
        }
    }

    private func startAnimations() {
        spin = false; pop = false
        if !reduceMotion { withAnimation(.linear(duration: 1)) { spin = true } }
        withAnimation(reduceMotion ? nil : Motion.bouncy.delay(0.05)) { pop = true }
        notifyHaptic()
    }

    private func notifyHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch outcome {
        case .success:  generator.notificationOccurred(.success)
        case .declined: generator.notificationOccurred(.error)
        case .processing: break
        }
        #endif
    }
}

#Preview("success") {
    CreditStatusView(outcome: .success, productKind: .cash, amount: 840_000,
                     caption: "Платёж 24 600 ₽/мес · 36 мес", onDone: {}, onRetry: {})
        .environment(\.theme, .default)
}

#Preview("declined") {
    CreditStatusView(outcome: .declined(.overDebtLoad), productKind: .cash, amount: 0,
                     caption: "", onDone: {}, onRetry: {})
        .environment(\.theme, .default)
}
