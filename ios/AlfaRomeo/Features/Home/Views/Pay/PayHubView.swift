import SwiftUI

/// Оплата (§10.3 / §9.1): быстрый выбор способа (сканировать QR, бесконтактно, СБП по телефону,
/// цифровой рубль) одним сгруппированным списком. Каждый способ заводит на **реальный** флоу: QR / СБП / цифр.₽ → существующий
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
            GroupedSection(footer: "Платёж подтверждается Face ID. Цифровой рубль массово внедряется с 01.09.2026, кошелёк и универсальный QR уже доступны.") {
                // QR — самый частый сценарий, первой строкой.
                methodRow(icon: "qrcode.viewfinder", title: "Сканировать QR",
                          subtitle: "QR-код продавца") {
                    scanning = true
                }
                methodRow(icon: "wave.3.right", title: "Бесконтактно",
                          subtitle: "Оплата через NFC") {
                    nfc = true
                }
                methodRow(icon: TransferKind.byPhone.icon,
                          title: "СБП по телефону", subtitle: TransferKind.byPhone.subtitle) {
                    router.push(PaymentsRoute.transfer(.byPhone))
                }
                methodRow(icon: TransferKind.digitalRubleQR.icon,
                          title: "Цифровой рубль", subtitle: TransferKind.digitalRubleQR.subtitle) {
                    router.push(PaymentsRoute.transfer(.digitalRubleQR))
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
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

    private func methodRow(icon: String, title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, subtitle: subtitle, showsChevron: true)
        }
        .buttonStyle(.row)
    }
}

/// Облегчённое бесконтактное проведение (§10.3). Реальной NFC-оплаты на симуляторе нет, поэтому это
/// честное демо-проведение: «приложите телефон», короткая обработка, затем переиспользуемый
/// анимированный ``OperationStatusView`` (успех). На устройстве здесь была бы NFC + Face ID.
private struct NFCPaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private enum Phase { case ready, processing, done }
    @State private var phase: Phase = .ready

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
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)
            GlyphCircle(systemImage: "wave.3.right", size: 88)
            VStack(spacing: Spacing.sm) {
                Text("Приложите телефон к терминалу")
                    .font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("На устройстве оплата проходит через NFC и Face ID. На симуляторе это демо-проведение для проверки потока.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.lg)
            PrimaryButton(title: "Оплатить в демо-режиме", icon: "faceid") { start() }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }

    private func start() {
        phase = .processing
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            phase = .done
        }
    }
}
