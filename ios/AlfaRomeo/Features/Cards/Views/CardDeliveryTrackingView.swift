import SwiftUI

/// Доставка карты: animated delivery tracking + activation (§6.2 step 5). Reached from the cards
/// list / detail for an in-flight order, and embedded as the final step of the order wizard.
struct CardDeliveryTrackingView: View {
    let orderId: String

    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session
    @State private var store = CardsStore.shared

    var body: some View {
        ScrollView {
            DeliveryTrackingContent(orderId: orderId) { router.pop() }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.md)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Доставка карты")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(api: api, profileId: session.activeProfile?.id ?? "") }
    }
}

/// Shared tracking body: card face, animated stepper, shipment facts, and the activation control.
/// Auto-advances ordered → печать → в пути on its own (the "анимированные статусы" wow), then leaves
/// delivery + activation under manual control for the demo finale.
struct DeliveryTrackingContent: View {
    let orderId: String
    var onDone: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = CardsStore.shared
    @State private var activating = false

    private var order: DeliveryOrder? { store.order(id: orderId) }
    private var linkedCard: CardItem? { order?.cardId.flatMap { store.card(id: $0) } }

    /// Activated = the linked plastic has flipped to active (or there's no card to activate).
    private var activated: Bool {
        guard let order, order.status == .delivered else { return false }
        guard let card = linkedCard else { return true }
        return card.state == .active
    }

    var body: some View {
        if let order {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let card = linkedCard {
                    CardFaceView(card: card).frame(maxWidth: 280).frame(maxWidth: .infinity)
                }

                GroupedSection {
                    statusRow(order)
                    DeliveryStepper(status: order.status)
                        .padding(.vertical, Spacing.md)
                    fact("Трек-номер", order.tracking, mono: true)
                    fact("Способ", "\(order.method.label) · \(order.method.detail)")
                    fact("Адрес", order.address)
                }

                actions(order)
            }
            .animation(reduceMotion ? nil : Motion.smooth, value: order.status)
            .animation(reduceMotion ? nil : Motion.smooth, value: activated)
            // Gentle auto-progression; activation stays manual.
            .task(id: order.status) {
                guard let delay = autoAdvanceDelay(order.status) else { return }
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                store.advanceDelivery(orderId: orderId)
            }
        } else {
            ContentUnavailableLikeView()
        }
    }

    @ViewBuilder
    private func statusRow(_ order: DeliveryOrder) -> some View {
        if activated {
            statusText(title: "Карта активирована", message: "Готова к оплатам и добавлению в Apple Pay.",
                       tint: theme.success)
        } else if order.status == .delivered {
            statusText(title: "Карта доставлена",
                       message: "Активируйте по прибытии: приложите карту (NFC) или введите код из СМС.")
        } else {
            statusText(title: order.status.title, message: etaText(order))
        }
    }

    @ViewBuilder
    private func actions(_ order: DeliveryOrder) -> some View {
        if activated {
            PrimaryButton(title: "Готово") { onDone() }
        } else if order.status == .delivered {
            PrimaryButton(title: activating ? "Активация…" : "Активировать (NFC / код)",
                          isLoading: activating) {
                activating = true
                store.activate(orderId: orderId)
                withAnimation(Motion.smooth) { activating = false }
            }
        } else {
            #if DEBUG
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Продвинуть статус (демо)") {
                    store.advanceDelivery(orderId: orderId)
                }
                if order.status == .shipping {
                    SecondaryButton(title: "Отметить доставленной") {
                        store.setDeliveryStatus(.delivered, orderId: orderId)
                    }
                }
            }
            #endif
        }
    }

    /// Заказана и печать move on by themselves. A release build has no demo controls, so «в пути»
    /// also arrives on its own there and activation stays reachable; a debug build keeps «в пути»
    /// for the manual controls above.
    private func autoAdvanceDelay(_ status: PhysicalCardStatus) -> Duration? {
        switch status {
        case .ordered, .printing: return .seconds(1.8)
        #if !DEBUG
        case .shipping: return .seconds(6)
        #endif
        default: return nil
        }
    }

    private func etaText(_ order: DeliveryOrder) -> String {
        switch order.status {
        case .ordered:  return "Заявка принята, готовим к печати."
        case .printing: return "Карта печатается и персонализируется."
        case .shipping: return "Курьер в пути, \(order.method.detail)."
        default:        return ""
        }
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(mono ? BrandFont.mono(17) : BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private func statusText(title: String, message: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BrandFont.headline).foregroundStyle(tint ?? theme.textPrimary)
            if !message.isEmpty {
                Text(message).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
    }
}

/// Lightweight "order not found" placeholder (avoids depending on iOS-17 `ContentUnavailableView`
/// styling specifics; keeps the module self-contained).
private struct ContentUnavailableLikeView: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: Spacing.sm) {
            GlyphCircle(systemImage: "shippingbox", size: 56)
            Text("Доставка не найдена").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }
}
