import SwiftUI

/// The order book (стакан) for the trading detail (§9.6). Bybit layout & density on the brand palette:
/// asks (sell) on top in **red**, bids (buy) below in **green**, the large live price centred with an
/// `≈ $` line under it, cumulative-depth bars behind each row, and a B%/S% ratio bar. Depth is mocked
/// around the live mid (``OrderBook``, §11.4). Tapping a level pushes the order ticket prefilled at
/// that price (ask → buy, bid → sell). Reads the ambient `theme.*` tokens (light, like the rest of the app).
struct OrderBookView: View {
    let symbol: String
    /// (price, side) for the tapped level — ask = buy into the offer, bid = sell into the bid.
    var onSelect: (Double, CryptoSide) -> Void

    @Environment(\.theme) private var theme
    @State private var prices = LivePriceService.shared

    private var mid: Double { prices.price(symbol) }
    private var book: OrderBook { OrderBook.make(symbol: symbol, mid: mid) }
    private var change: Double? { prices.change24h(symbol) }
    private var usd: Double { let u = prices.price("USDT"); return u > 0 ? mid / u : 0 }

    var body: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: Spacing.xs) {
                header
                ForEach(book.asks) { row($0) }
                centre
                ForEach(book.bids) { row($0) }
                ratioBar
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Стакан").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
            Spacer()
            Text("Цена, ₽").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Spacer()
            Text("Объём").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xxs)
    }

    private func row(_ level: OrderBookLevel) -> some View {
        let tint = level.side == .ask ? theme.danger : theme.success
        let side: CryptoSide = level.side == .ask ? .buy : .sell
        return Button { onSelect(level.price, side) } label: {
            ZStack(alignment: .trailing) {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: max(2, geo.size.width * level.depthFraction))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack {
                    Text(priceStr(level.price)).font(BrandFont.mono(12, weight: .medium)).foregroundStyle(tint)
                    Spacer()
                    Text(CryptoFormat.qty(level.size)).font(BrandFont.mono(12)).foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, Spacing.sm)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.99))
    }

    private var centre: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: (change ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(changeColor)
            Text(priceStr(mid))
                .font(BrandFont.mono(22, weight: .semibold))
                .foregroundStyle(changeColor)
                .monospacedDigit()
            Spacer()
            Text("≈ $\(usdStr)")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    private var ratioBar: some View {
        HStack(spacing: Spacing.sm) {
            Text("B \(book.bidPercent)%").font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.success)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(theme.success).frame(width: max(0, geo.size.width * book.bidShare))
                    Rectangle().fill(theme.danger)
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())
            Text("\(book.askPercent)% S").font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.danger)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xxs)
    }

    private var changeColor: Color {
        guard let change else { return theme.textPrimary }
        return change >= 0 ? theme.success : theme.danger
    }

    private func priceStr(_ p: Double) -> String {
        CryptoFormat.rub(p, fraction: p >= 1000 ? 0 : 2).replacingOccurrences(of: " ₽", with: "")
    }
    private var usdStr: String {
        CryptoFormat.rub(usd, fraction: usd >= 1000 ? 0 : 2).replacingOccurrences(of: " ₽", with: "")
    }
}
