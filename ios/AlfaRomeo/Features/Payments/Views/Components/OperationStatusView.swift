import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Animated operation status (§9.2 / §13.1): в обработке → успех / отклонено + причина. A single
/// medallion morphs between states — a rotating ring while processing, a spring-scaled checkmark on
/// success, a danger medallion + reason on decline. Honors Reduce Motion.
struct OperationStatusView: View {
    let outcome: OperationOutcome
    var amount: Double
    var currency: String
    var recipientName: String
    var onRetry: () -> Void
    var onClose: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell: ShellState?   // optional → Previews need not inject it

    @State private var spin = false
    @State private var pop = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.xl)

            medallion

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(BrandFont.title)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)
            }

            if !isProcessing {
                AmountText(amount: amount, currency: currency, size: 24)
                    .padding(.top, Spacing.xs)
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
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 132, height: 132)
                .scaleEffect(isProcessing && !reduceMotion ? (spin ? 1.06 : 0.94) : 1)
                .animation(isProcessing && !reduceMotion
                           ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : nil,
                           value: spin)

            if isProcessing {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false),
                               value: spin)
            } else {
                Circle()
                    .stroke(tint, lineWidth: 4)
                    .frame(width: 104, height: 104)
            }

            Image(systemName: symbol)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(tint)
                .scaleEffect(pop ? 1 : 0.4)
                .opacity(pop ? 1 : 0)
        }
        .accessibilityLabel(title)
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        switch outcome {
        case .processing:
            EmptyView()
        case .success:
            PrimaryButton(title: "Готово", icon: "checkmark") { onClose() }
        case .declined(let reason):
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Повторить", icon: "arrow.clockwise") { onRetry() }
                SecondaryButton(title: "Спросить у AI", icon: "sparkles") {
                    shell?.showCopilot(.declined(reason: reason.title))
                }
                SecondaryButton(title: "Закрыть") { onClose() }
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
        case .success:    return "checkmark"
        case .declined(let reason): return reason.systemImage
        }
    }

    private var title: String {
        switch outcome {
        case .processing: return "В обработке"
        case .success:    return "Готово"
        case .declined(let reason): return reason.title
        }
    }

    private var subtitle: String {
        switch outcome {
        case .processing: return "Подтверждаем операцию…"
        case .success:    return "\(recipientName) получит перевод мгновенно."
        case .declined(let reason): return reason.message
        }
    }

    /// A stable key so `.onChange` fires on every state transition (incl. decline-reason swaps).
    private var outcomeKey: String {
        switch outcome {
        case .processing: return "p"
        case .success:    return "s"
        case .declined(let r): return "d-\(r)"
        }
    }

    private func startAnimations() {
        spin = false
        pop = false
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

#Preview {
    OperationStatusView(outcome: .declined(.insufficientFunds), amount: 190_000, currency: "₽",
                        recipientName: "Иван Петров", onRetry: {}, onClose: {})
        .environment(\.theme, .default)
}
