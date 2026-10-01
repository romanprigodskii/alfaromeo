import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Open-deposit / stake outcome (§10.6), in the §9.2 status language: обработка → успех / отклонено +
/// причина. One flat medallion changes state; only the processing ring moves. Honors Reduce Motion.
struct SavingsStatusView: View {
    let outcome: SavingsOutcome
    var successTitle: String       // e.g. "Вклад открыт" / "Стейкинг активен"
    var amountRub: Double
    var caption: String            // e.g. "17,2 % годовых · 6 мес"
    var onDone: () -> Void
    var onRetry: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell: ShellState?   // optional → Previews need not inject it

    @State private var spin = false
    @State private var shown = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)

            medallion

            VStack(spacing: Spacing.sm) {
                Text(headline)
                    .font(BrandFont.title1)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if case .success = outcome {
                VStack(spacing: Spacing.xs) {
                    AmountText(amount: amountRub, size: 34, splitsKopecks: true)
                    Text(caption)
                        .font(BrandFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer(minLength: Spacing.lg)

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.md)
        .background(theme.background.ignoresSafeArea())
        .onAppear { startAnimations() }
        .onChange(of: outcomeKey) { _, _ in startAnimations() }
        .animation(reduceMotion ? nil : Motion.smooth, value: outcomeKey)
    }

    // MARK: Medallion

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(theme.fill)
                .frame(width: 96, height: 96)

            if isProcessing {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false),
                               value: spin)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(tint)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            }
        }
        .accessibilityLabel(headline)
    }

    @ViewBuilder private var actions: some View {
        switch outcome {
        case .processing:
            EmptyView()
        case .success:
            PrimaryButton(title: "Готово") { onDone() }
        case .declined(let reason):
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Повторить") { onRetry() }
                SecondaryButton(title: "Спросить у AI") {
                    shell?.showCopilot(.declined(reason: reason.title))
                }
                TertiaryButton("Закрыть") { onDone() }
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

    private var headline: String {
        switch outcome {
        case .processing: return "В обработке"
        case .success:    return successTitle
        case .declined(let reason): return reason.title
        }
    }

    /// Success carries its data (amount + terms) below, so it needs no extra sentence.
    private var subtitle: String? {
        switch outcome {
        case .processing: return "Подтверждаем операцию"
        case .success:    return nil
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
        spin = false
        shown = false
        if !reduceMotion { withAnimation(.linear(duration: 1)) { spin = true } }
        withAnimation(reduceMotion ? nil : Motion.smooth) { shown = true }
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
    SavingsStatusView(outcome: .success, successTitle: "Вклад открыт", amountRub: 500_000,
                      caption: "17,2 % годовых · 6 мес", onDone: {}, onRetry: {})
        .environment(\.theme, .default)
}
