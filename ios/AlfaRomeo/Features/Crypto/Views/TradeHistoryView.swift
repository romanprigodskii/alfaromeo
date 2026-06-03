import SwiftUI

/// История сделок (§9.6): unified feed of crypto trades, converts, sends, receives and ЦФА purchases,
/// plus open limit orders. Reflects the live mutations made in this session (``CryptoStore``).
struct TradeHistoryView: View {
    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var cancelTarget: Order?

    private var openOrders: [Order] { store.orders.filter { $0.status == .open } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !openOrders.isEmpty { openOrdersSection }
                activitySection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("История сделок")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var openOrdersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Открытые ордера").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(openOrders.enumerated()), id: \.element.id) { index, order in
                        if index > 0 { Divider().overlay(theme.border) }
                        HStack(spacing: Spacing.md) {
                            AssetGlyph(symbol: order.asset, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(order.side == .buy ? "Покупка" : "Продажа") \(order.asset)")
                                    .font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                                Text("Лимит · \(CryptoFormat.qty(order.qty, symbol: order.asset))")
                                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            }
                            Spacer(minLength: Spacing.sm)
                            VStack(alignment: .trailing, spacing: 2) {
                                if let price = order.price {
                                    Text(CryptoFormat.rub(price, fraction: 0)).font(BrandFont.callout.weight(.medium))
                                        .foregroundStyle(theme.textPrimary).monospacedDigit()
                                }
                                StatusPill(status: .pending, text: "В книге")
                            }
                            Menu {
                                Button(role: .destructive) { cancelTarget = order } label: {
                                    Label("Отменить ордер", systemImage: "xmark.circle")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(theme.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Действия с ордером")
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }
            }
        }
        .confirmationDialog(
            cancelTarget.map { "Отменить лимит-ордер на \($0.asset)?" } ?? "Отменить ордер?",
            isPresented: Binding(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Отменить ордер", role: .destructive) {
                if let id = cancelTarget?.id { withAnimation { store.cancelOrder(id: id) } }
                cancelTarget = nil
            }
            Button("Оставить", role: .cancel) { cancelTarget = nil }
        } message: {
            Text("Ордер ещё не исполнен — средства не списаны. Он будет снят из книги заявок.")
        }
    }

    @ViewBuilder private var activitySection: some View {
        Text("Операции").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
        if store.activity.isEmpty {
            ContentUnavailableView("Пока нет операций", systemImage: "clock",
                                   description: Text("Покупки, обмены и переводы появятся здесь."))
                .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
        } else {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(store.activity.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(theme.border) }
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: CryptoActivity) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill((theme.accentCrypto.first ?? theme.accent).opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: item.kind.icon).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary).lineLimit(1)
                Text("\(item.kind.label) · \(item.subtitle)").font(BrandFont.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                if item.rubAmount != 0 {
                    AmountText(amount: item.rubAmount, size: 15, showsSign: true, colorBySign: true)
                } else {
                    Text(CryptoFormat.qty(item.qty, symbol: item.asset)).font(BrandFont.amountS).foregroundStyle(theme.textPrimary)
                }
                Text(Self.dateLabel(item.at)).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "d MMM, HH:mm"
        return f
    }()
    private static func dateLabel(_ date: Date) -> String { dateFormatter.string(from: date) }
}

#Preview {
    NavigationStack {
        TradeHistoryView()
            .environment(\.theme, .default)
    }
}
