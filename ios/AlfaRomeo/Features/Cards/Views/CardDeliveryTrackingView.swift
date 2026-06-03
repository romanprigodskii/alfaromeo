import SwiftUI

/// Доставка карты — animated delivery tracking + activation (§6.2 step 5). Reached from the cards
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
                .padding(Spacing.lg)
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

                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        DeliveryStepper(status: order.status)
                        Divider().overlay(theme.border)
                        fact("Трек-номер", order.tracking, mono: true)
                        fact("Способ", "\(order.method.label) · \(order.method.detail)")
                        fact("Адрес", order.address)
                    }
                }

                statusBanner(order)
                actions(order)
            }
            .animation(reduceMotion ? nil : Motion.smooth, value: order.status)
            .animation(reduceMotion ? nil : Motion.smooth, value: activated)
            // Gentle auto-progression up to «в пути»; delivery + activation stay manual.
            .task(id: order.status) {
                guard order.status == .ordered || order.status == .printing else { return }
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                store.advanceDelivery(orderId: orderId)
            }
        } else {
            ContentUnavailableLikeView()
        }
    }

    @ViewBuilder
    private func statusBanner(_ order: DeliveryOrder) -> some View {
        if activated {
            banner(icon: "checkmark.seal.fill", tint: theme.success,
                   title: "Карта активирована", message: "Готова к оплатам и добавлению в Apple Pay.")
        } else if order.status == .delivered {
            banner(icon: "shippingbox.fill", tint: theme.accent,
                   title: "Карта доставлена", message: "Активируйте по прибытии: приложите карту (NFC) или введите код из СМС.")
        } else {
            banner(icon: order.status.icon, tint: theme.accent,
                   title: order.status.title, message: etaText(order))
        }
    }

    @ViewBuilder
    private func actions(_ order: DeliveryOrder) -> some View {
        if activated {
            PrimaryButton(title: "Готово", icon: "checkmark") { onDone() }
        } else if order.status == .delivered {
            PrimaryButton(title: activating ? "Активация…" : "Активировать (NFC / код)",
                          icon: "wave.3.right", isLoading: activating) {
                activating = true
                store.activate(orderId: orderId)
                withAnimation(Motion.smooth) { activating = false }
            }
        } else {
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Продвинуть статус (демо)", icon: "forward.fill") {
                    store.advanceDelivery(orderId: orderId)
                }
                if order.status == .shipping {
                    SecondaryButton(title: "Отметить доставленной") {
                        store.setDeliveryStatus(.delivered, orderId: orderId)
                    }
                }
            }
        }
    }

    private func etaText(_ order: DeliveryOrder) -> String {
        switch order.status {
        case .ordered:  return "Заявка принята, готовим к печати."
        case .printing: return "Карта печатается и персонализируется."
        case .shipping: return "Курьер в пути — \(order.method.detail)."
        default:        return ""
        }
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(mono ? BrandFont.mono(14) : BrandFont.callout)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func banner(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(message).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

/// Lightweight "order not found" placeholder (avoids depending on iOS-17 `ContentUnavailableView`
/// styling specifics; keeps the module self-contained).
private struct ContentUnavailableLikeView: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "shippingbox").font(.system(size: 32)).foregroundStyle(theme.textSecondary)
            Text("Доставка не найдена").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }
}
