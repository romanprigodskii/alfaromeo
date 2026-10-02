import SwiftUI

// MARK: - Formatting

extension PriceAlert {
    /// ₽ price for alert copy: whole roubles from 1 000 ₽ up, kopecks below.
    static func rub(_ value: Double) -> String {
        CryptoFormat.rub(value, fraction: abs(value) >= 1000 ? 0 : 2)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    static func date(_ date: Date) -> String { dateFormatter.string(from: date) }
}

// MARK: - Asset section

/// «Уведомить о цене» + «Алерты» for one asset (crypto detail and MOEX detail). The footer says
/// honestly that only live prices are checked.
struct PriceAlertsSection: View {
    let asset: String
    let market: PriceAlert.Market
    /// «Bitcoin», «Сбербанк».
    let assetTitle: String
    /// Current ₽ price for the prefill and the distance column; nil disables creation.
    let currentPrice: Double?
    let isLive: Bool

    @Environment(\.theme) private var theme
    @State private var store = PriceAlertsStore.shared
    @State private var creating: Bool

    init(asset: String, market: PriceAlert.Market, assetTitle: String, currentPrice: Double?,
         isLive: Bool, startCreating: Bool = false) {
        self.asset = asset
        self.market = market
        self.assetTitle = assetTitle
        self.currentPrice = currentPrice
        self.isLive = isLive
        _creating = State(initialValue: startCreating)
    }

    private var footer: String {
        isLive
            ? "Алерты проверяются только по живым ценам: сервер банка, биржа или Мосбиржа. Демо-цены их не запускают."
            : "Сейчас показаны демо-цены, поэтому проверка алертов на паузе. Она продолжится, когда вернётся живой источник."
    }

    var body: some View {
        let list = store.alerts(for: asset, market: market)
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GroupedSection(footer: footer) {
                Button { creating = true } label: {
                    ListRow(icon: "bell", title: "Уведомить о цене",
                            subtitle: "Когда цена станет выше или ниже", showsChevron: true)
                }
                .buttonStyle(.row)
                .disabled(currentPrice == nil)
            }
            if !list.isEmpty {
                GroupedSection("Алерты", footer: "Смахните алерт влево, чтобы удалить.") {
                    ForEach(list) { alert in
                        SwipeToDeleteRow { store.delete(alert.id) } content: {
                            PriceAlertRow(alert: alert, currentPrice: currentPrice)
                        }
                    }
                }
            }
        }
        .animation(Motion.snappy, value: list.map(\.id))
        .bottomSheet(isPresented: $creating, detents: [.medium, .large]) {
            if let currentPrice {
                PriceAlertSheet(asset: asset, market: market, assetTitle: assetTitle,
                                currentPrice: currentPrice, isLive: isLive) { creating = false }
            }
        }
    }
}

// MARK: - Row

/// One alert: direction glyph, threshold, state («ждёт» / «сработал»), distance to the current price.
struct PriceAlertRow: View {
    let alert: PriceAlert
    /// Settings list: prefix the asset name.
    var showsAsset = false
    var currentPrice: Double? = nil

    private var title: String {
        let price = PriceAlert.rub(alert.thresholdRub)
        return showsAsset
            ? "\(alert.assetTitle) \(alert.direction.phrase) \(price)"
            : "\(alert.direction.title) \(price)"
    }

    private var subtitle: String {
        if let at = alert.triggeredAt {
            let price = alert.triggeredPrice.map { " при \(PriceAlert.rub($0))" } ?? ""
            return "Сработал \(PriceAlert.date(at))\(price)"
        }
        return "Ждёт · создан \(PriceAlert.date(alert.createdAt))"
    }

    /// «+4,8 %»: how far the threshold is from the current price.
    private var distance: String? {
        guard alert.isActive, let currentPrice, currentPrice > 0 else { return nil }
        return CryptoFormat.pct((alert.thresholdRub / currentPrice - 1) * 100, fraction: 1)
    }

    var body: some View {
        ListRow(icon: alert.isActive ? alert.direction.icon : "checkmark",
                title: title, subtitle: subtitle, value: distance)
    }
}

// MARK: - Create sheet

/// «Уведомить о цене»: Выше / Ниже, a ₽ amount prefilled with the current price ± 5 %, «Создать».
struct PriceAlertSheet: View {
    let asset: String
    let market: PriceAlert.Market
    let assetTitle: String
    let currentPrice: Double
    let isLive: Bool
    var onDone: () -> Void

    @Environment(\.theme) private var theme
    @State private var direction: PriceAlert.Direction = .above
    @State private var text: String

    init(asset: String, market: PriceAlert.Market, assetTitle: String, currentPrice: Double,
         isLive: Bool, onDone: @escaping () -> Void) {
        self.asset = asset
        self.market = market
        self.assetTitle = assetTitle
        self.currentPrice = currentPrice
        self.isLive = isLive
        self.onDone = onDone
        _text = State(initialValue: Self.prefill(currentPrice, .above))
    }

    /// Current price ± 5 %, rounded to whole roubles from 100 ₽ up.
    static func prefill(_ price: Double, _ direction: PriceAlert.Direction) -> String {
        let target = price * (direction == .above ? 1.05 : 0.95)
        return MoneyFormat.number(target, maxFractionDigits: target >= 100 ? 0 : 2)
    }

    private var threshold: Double { CryptoFormat.parse(text) }

    private var isValid: Bool {
        threshold > 0 && (direction == .above ? threshold > currentPrice : threshold < currentPrice)
    }

    private var hint: (text: String, warning: Bool) {
        guard threshold > 0 else { return ("Укажите цену в рублях", true) }
        guard isValid else {
            return (direction == .above ? "Цена уже выше: укажите больше текущей"
                                        : "Цена уже ниже: укажите меньше текущей", true)
        }
        let pct = CryptoFormat.pct((threshold / currentPrice - 1) * 100, fraction: 1)
        return ("\(pct) от текущей цены", false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Уведомить о цене").font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                Text("\(assetTitle): сейчас \(PriceAlert.rub(currentPrice))")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).monospacedDigit()
            }
            Picker("Направление", selection: $direction) {
                ForEach(PriceAlert.Direction.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: direction) { _, new in text = Self.prefill(currentPrice, new) }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                TicketField(label: "Цена, ₽", text: $text, unit: "₽")
                Text(hint.text)
                    .font(BrandFont.footnote)
                    .foregroundStyle(hint.warning ? theme.statusInk(.warning) : theme.textSecondary)
                    .monospacedDigit()
            }

            PrimaryButton(title: "Создать") {
                PriceAlertsStore.shared.add(asset: asset, market: market, direction: direction,
                                            thresholdRub: threshold)
                onDone()
            }
            .disabled(!isValid)

            Text(isLive
                 ? "Пришлём уведомление, когда живая цена пересечёт порог. Алерт срабатывает один раз."
                 : "Сейчас демо-цены: алерт сработает только по живой цене, когда источник вернётся.")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Swipe to delete

/// Swipe-to-delete for a ``GroupedSection`` row (sections are not a `List`): drag left to reveal
/// «Удалить», or swipe far to delete at once. Long-press menu and a VoiceOver action do the same.
struct SwipeToDeleteRow<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme
    @State private var offset: CGFloat = 0
    @State private var isOpen = false

    private let reveal: CGFloat = 92
    private let fullSwipe: CGFloat = 200

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button(role: .destructive, action: delete) {
                    Text("Удалить")
                        .font(BrandFont.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: max(reveal, -offset))
                        .frame(maxHeight: .infinity)
                        .background(theme.danger)
                }
                .buttonStyle(.plain)
            }
            content()
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .offset(x: offset)
                .overlay {
                    if isOpen { Color.clear.contentShape(Rectangle()).onTapGesture { close() } }
                }
        }
        // GroupedSection pads rows horizontally; undo it so the red action sits flush with the edge.
        .padding(.horizontal, -Spacing.md)
        .clipped()
        .simultaneousGesture(drag)
        .contextMenu {
            Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityAction(named: "Удалить", onDelete)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = min(0, (isOpen ? -reveal : 0) + value.translation.width)
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let end = (isOpen ? -reveal : 0) + value.translation.width
                if end < -fullSwipe {
                    delete()
                } else if end < -reveal / 2 {
                    withAnimation(Motion.snappy) { offset = -reveal; isOpen = true }
                } else {
                    close()
                }
            }
    }

    private func close() {
        withAnimation(Motion.snappy) { offset = 0; isOpen = false }
    }

    private func delete() {
        withAnimation(Motion.snappy) { onDelete() }
    }
}

// MARK: - App-wide host

/// The in-app banner shown when an alert fires while the app is open.
struct PriceAlertBanner: View {
    let alert: PriceAlert
    var onClose: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm + 4) {
            GlyphCircle(systemImage: "bell", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(PriceAlertsStore.headline(alert))
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                if let price = alert.triggeredPrice {
                    Text("Сейчас \(PriceAlert.rub(price))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
            }
            .monospacedDigit()
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 4)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        // Floating element: the one soft shadow DESIGN.md allows.
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        .accessibilityElement(children: .combine)
    }
}

private struct PriceAlertHost: ViewModifier {
    @State private var store = PriceAlertsStore.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let alert = store.banner {
                    PriceAlertBanner(alert: alert) { store.dismissBanner() }
                        .padding(.horizontal, Spacing.screen)
                        .padding(.top, Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(Motion.snappy, value: store.banner?.id)
            .task { store.startMonitoring() }
            .task(id: store.activeMarkets) { await store.keepFeedsWarm() }
    }
}

extension View {
    /// Evaluates price alerts app-wide and shows the in-app banner when one fires.
    func priceAlertHost() -> some View { modifier(PriceAlertHost()) }
}
