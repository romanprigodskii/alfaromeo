import SwiftUI

/// Оплата (§10.3 / §9.1) — быстрый выбор способа: сканировать QR, бесконтактно (NFC), СБП по телефону,
/// цифровой рубль. Каждый способ заводит на **реальный** флоу: QR / СБП / цифр.₽ → существующий
/// ``TransferFlowView`` (через ``PaymentsRoute``), NFC → облегчённое tap-to-pay со статусом операции.
///
/// Экран Платежей (вход — `PaymentsRoute.pay` из ``PaymentsView``). `PaymentsRoute` регистрирует
/// host-стек Платежей, поэтому рельсы переводов отсюда резолвятся на нём. Биометрия и анимированный
/// статус живут в переиспользуемых компонентах Платежей — этот экран только выбирает рельс.
struct PayHubView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var scanning = false
    @State private var nfc = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Выберите способ — дальше подключим перевод по нужному рельсу с подтверждением Face ID (§10.3).")
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)

                // QR — самый частый сценарий, отдельной крупной плиткой.
                scanCard

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        methodRow(icon: "wave.3.right.circle.fill", tint: theme.accent,
                                  title: "Бесконтактно (NFC)", subtitle: "Приложите телефон к терминалу") {
                            nfc = true
                        }
                        divider
                        methodRow(icon: TransferKind.byPhone.icon, tint: theme.accent,
                                  title: "СБП по телефону", subtitle: TransferKind.byPhone.subtitle) {
                            router.push(PaymentsRoute.transfer(.byPhone))
                        }
                        divider
                        methodRow(icon: TransferKind.digitalRubleQR.icon, tint: theme.accentCrypto.first,
                                  title: "Цифровой рубль", subtitle: TransferKind.digitalRubleQR.subtitle) {
                            router.push(PaymentsRoute.transfer(.digitalRubleQR))
                        }
                    }
                }

                Text("Цифровой рубль массово внедряется с 01.09.2026 — кошелёк и универсальный QR уже доступны здесь.")
                    .font(BrandFont.micro)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Оплата")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .sheet(isPresented: $scanning) {
            // Переиспользуем sim-safe AVFoundation-сканер из Крипто (единый компонент, не дубль).
            QRScannerView(asset: "RUB") { _ in
                // Считали QR продавца → ведём в перевод цифровым рублём (универсальный QR / C2C, §10.3).
                router.push(PaymentsRoute.transfer(.digitalRubleQR))
            }
        }
        .sheet(isPresented: $nfc) { NFCPaySheet() }
    }

    private var scanCard: some View {
        Button { scanning = true } label: {
            SurfaceCard {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(theme.cryptoGradient,
                                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сканировать QR")
                            .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("Оплата по QR-коду продавца")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func methodRow(icon: String, tint: Color?, title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, iconTint: tint, title: title, subtitle: subtitle, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View { Divider().overlay(theme.border) }
}

/// Облегчённое бесконтактное проведение (§10.3). Реальной NFC-оплаты на симуляторе нет, поэтому это
/// честное демо-проведение: «приложите телефон» → короткая обработка → переиспользуемый
/// анимированный ``OperationStatusView`` (успех). На устройстве здесь была бы NFC + Face ID.
private struct NFCPaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case ready, processing, done }
    @State private var phase: Phase = .ready
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .ready:
                    ready
                case .processing, .done:
                    OperationStatusView(
                        outcome: phase == .done ? .success : .processing,
                        amount: 1_290, currency: "₽", recipientName: "Кофейня «Согрев»",
                        onRetry: { start() }, onClose: { dismiss() })
                }
            }
            .navigationTitle("Бесконтактно")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } }
            }
        }
    }

    private var ready: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.xl)
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(theme.accent)
                .scaleEffect(pulse && !reduceMotion ? 1.06 : 0.96)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                           value: pulse)
            VStack(spacing: Spacing.sm) {
                Text("Приложите телефон к терминалу")
                    .font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("На устройстве оплата проходит через NFC и Face ID. На симуляторе — демо-проведение для проверки потока.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.lg)
            Spacer(minLength: Spacing.lg)
            PrimaryButton(title: "Оплатить · демо", icon: "faceid") { start() }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .onAppear { pulse = true }
    }

    private func start() {
        phase = .processing
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            phase = .done
        }
    }
}
