import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Animated operation status for the crypto hub (§10.8) — the ``OperationStatusView`` pattern with
/// crypto copy and the extra decline reasons (сеть перегружена / курс устарел). A medallion morphs
/// processing → success / declined; honors Reduce Motion. Success copy is supplied per flow.
struct CryptoStatusView: View {
    let outcome: CryptoOutcome
    var successTitle: String = "Готово"
    var successDetail: String = "Операция выполнена."
    var amount: Double = 0
    var currency: String = "₽"
    var onRetry: () -> Void = {}
    var onClose: () -> Void = {}

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
                Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)
            }
            if !outcome.isProcessing, amount != 0 {
                AmountText(amount: amount, currency: currency, size: 24).padding(.top, Spacing.xs)
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

    private var medallion: some View {
        ZStack {
            Circle().fill(tint.opacity(0.14)).frame(width: 132, height: 132)
                .scaleEffect(outcome.isProcessing && !reduceMotion ? (spin ? 1.06 : 0.94) : 1)
                .animation(outcome.isProcessing && !reduceMotion
                           ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : nil, value: spin)
            if outcome.isProcessing {
                Circle().trim(from: 0, to: 0.72)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: spin)
            } else {
                Circle().stroke(tint, lineWidth: 4).frame(width: 104, height: 104)
            }
            Image(systemName: symbol)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(tint)
                .scaleEffect(pop ? 1 : 0.4)
                .opacity(pop ? 1 : 0)
        }
        .accessibilityLabel(title)
    }

    @ViewBuilder private var actions: some View {
        switch outcome {
        case .processing:
            EmptyView()
        case .success:
            PrimaryButton(title: "Готово", icon: "checkmark") { onClose() }
        case .declined(let r):
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Повторить", icon: "arrow.clockwise") { onRetry() }
                SecondaryButton(title: "Спросить у AI", icon: "sparkles") {
                    shell?.showCopilot(.declined(reason: r.title))
                }
                SecondaryButton(title: "Закрыть") { onClose() }
            }
        }
    }

    private var tint: Color {
        switch outcome {
        case .processing: return theme.accent
        case .success:    return theme.success
        case .declined(let r):
            switch r {
            case .networkBusy, .quoteExpired: return theme.warning
            default:                          return theme.danger
            }
        }
    }
    private var symbol: String {
        switch outcome {
        case .processing: return "arrow.triangle.2.circlepath"
        case .success:    return "checkmark"
        case .declined(let r): return r.systemImage
        }
    }
    private var title: String {
        switch outcome {
        case .processing: return "В обработке"
        case .success:    return successTitle
        case .declined(let r): return r.title
        }
    }
    private var subtitle: String {
        switch outcome {
        case .processing: return "Исполняем по live-курсу…"
        case .success:    return successDetail
        case .declined(let r): return r.message
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
        let g = UINotificationFeedbackGenerator()
        switch outcome {
        case .success:  g.notificationOccurred(.success)
        case .declined: g.notificationOccurred(.error)
        case .processing: break
        }
        #endif
    }
}

#Preview {
    CryptoStatusView(outcome: .declined(.networkBusy), successTitle: "Обмен выполнен",
                     successDetail: "Средства зачислены.", amount: 0.1, currency: "BTC",
                     onRetry: {}, onClose: {})
        .environment(\.theme, .default)
}
