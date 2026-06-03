import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Animated acquiring outcome screen (§ Ромео-Бизнес «Эквайринг») — mirrors the crypto
/// ``CryptoStatusView`` pattern with acquiring copy. A medallion morphs
/// processing → settled(success) / declined; honors Reduce Motion. On `.settled` it shows the
/// credited amount + the full ``AcquiringReceiptCard``; on `.declined` it offers retry / close.
struct AcquiringStatusView: View {
    let outcome: AcquiringOutcome
    var onClose: () -> Void
    var onRetry: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell: ShellState?   // optional → Previews need not inject it
    @State private var spin = false
    @State private var pop = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if case .settled = outcome {
                settledContent
            } else {
                Spacer(minLength: Spacing.xl)
                medallion
                titleBlock
                Spacer(minLength: Spacing.lg)
                actions
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
        .background(theme.background.ignoresSafeArea())
        .onAppear { startAnimations() }
        .onChange(of: outcomeKey) { _, _ in startAnimations() }
        .animation(reduceMotion ? nil : Motion.smooth, value: outcomeKey)
    }

    // MARK: Settled layout (receipt)

    @ViewBuilder private var settledContent: some View {
        if case .settled(let receipt) = outcome {
            VStack(spacing: Spacing.lg) {
                medallion
                titleBlock
                AmountText(amount: receipt.creditedRub, size: 26)
                    .foregroundStyle(theme.success)
                ScrollView {
                    AcquiringReceiptCard(receipt: receipt)
                        .padding(.bottom, Spacing.sm)
                }
                PrimaryButton(title: "Готово", icon: "checkmark") { onClose() }
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: Spacing.sm) {
            Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: Medallion

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
        case .settled:
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

    // MARK: Per-case styling

    private var tint: Color {
        switch outcome {
        case .processing: return theme.accent
        case .settled:    return theme.success
        case .declined:   return theme.danger
        }
    }
    private var symbol: String {
        switch outcome {
        case .processing: return "arrow.triangle.2.circlepath"
        case .settled:    return "checkmark"
        case .declined(let r): return r.systemImage
        }
    }
    private var title: String {
        switch outcome {
        case .processing: return "Принимаем оплату"
        case .settled:    return "Оплата принята"
        case .declined(let r): return r.title
        }
    }
    private var subtitle: String {
        switch outcome {
        case .processing: return "Зачисляем по live-курсу…"
        case .settled:    return "Средства зачислены на расчётный счёт."
        case .declined(let r): return r.message
        }
    }
    private var outcomeKey: String {
        switch outcome {
        case .processing: return "p"
        case .settled(let receipt): return "s-\(receipt.id)"
        case .declined(let r): return "d-\(r)"
        }
    }

    // MARK: Animation + haptics

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
        case .settled:    g.notificationOccurred(.success)
        case .declined:   g.notificationOccurred(.error)
        case .processing: break
        }
        #endif
    }
}

private struct AcquiringStatusView_PreviewHost: View {
    var body: some View {
        let receipt = AcquiringReceipt(
            id: "rcpt-1", receiptNo: "AR-2035-0042", method: .crypto,
            grossAmount: 100, payCurrency: "USDT",
            creditedRub: 9_910, feeRub: 90,
            liveRate: 100, cryptoAmount: 100, cryptoAsset: "USDT",
            createdAt: Date()
        )
        return VStack {
            AcquiringStatusView(outcome: .settled(receipt), onClose: {}, onRetry: {})
        }
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}

#Preview {
    AcquiringStatusView_PreviewHost()
}
