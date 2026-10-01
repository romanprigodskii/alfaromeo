import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Operation status (§9.2): в обработке → успех / отклонено + причина. A single medallion changes
/// with the state: a rotating ring while processing, a checkmark on success, a danger mark + reason
/// on decline. Motion only conveys state; honors Reduce Motion.
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
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)

            medallion

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(BrandFont.title1)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.md)
            }

            if !isProcessing {
                AmountText(amount: amount, currency: currency, size: 28)
            }

            Spacer(minLength: Spacing.lg)

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.md)
        .background(theme.background.ignoresSafeArea())
        .onAppear { startAnimations() }
        .onChange(of: outcomeKey) { _, _ in startAnimations() }
        .animation(reduceMotion ? nil : Motion.smooth, value: outcomeKey)
    }

    // MARK: Medallion

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(isProcessing ? theme.fill : tint.opacity(0.12))
                .frame(width: 96, height: 96)

            if isProcessing {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(theme.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false),
                               value: spin)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(tint)
                    .scaleEffect(pop ? 1 : 0.8)
                    .opacity(pop ? 1 : 0)
            }
        }
        .accessibilityLabel(title)
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        switch outcome {
        case .processing:
            EmptyView()
        case .success:
            PrimaryButton(title: "Готово") { onClose() }
        case .declined(let reason):
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Повторить") { onRetry() }
                SecondaryButton(title: "Спросить у AI") {
                    shell?.showCopilot(.declined(reason: reason.title))
                }
                TertiaryButton("Закрыть") { onClose() }
            }
        }
    }

    // MARK: Derived

    private var isProcessing: Bool { if case .processing = outcome { return true }; return false }

    private var tint: Color {
        switch outcome {
        case .processing: return theme.textPrimary
        case .success:    return theme.statusInk(.success)
        case .declined:   return theme.statusInk(.danger)
        }
    }

    private var symbol: String {
        switch outcome {
        case .processing: return "arrow.triangle.2.circlepath"
        case .success:    return "checkmark"
        case .declined(let reason): return GlyphCircle.outlineSymbol(reason.systemImage)
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
        withAnimation(reduceMotion ? nil : Motion.smooth) { pop = true }
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
