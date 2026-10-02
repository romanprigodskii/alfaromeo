import SwiftUI

/// Pure SwiftUI (no WidgetKit) so the layouts can also be rendered off-device for a snapshot.
enum WidgetSize { case small, medium }

/// DESIGN.md §1 tokens, duplicated so the extension stays self-contained.
struct WTheme {
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let border: Color
    let accent: Color
    let onAccent: Color
    let success: Color

    init(_ scheme: ColorScheme) {
        let dark = scheme == .dark
        surface       = Color(rgb: dark ? 0x1A1818 : 0xFDFCFC)
        textPrimary   = Color(rgb: dark ? 0xF4F2F1 : 0x141213)
        textSecondary = Color(rgb: dark ? 0x9C9795 : 0x6E6A69)
        textTertiary  = Color(rgb: dark ? 0x6A6563 : 0xA39E9C)
        border        = Color(rgb: dark ? 0x2E2B2A : 0xE6E3E1)
        accent        = Color(rgb: dark ? 0xF0302A : 0xD3140F)
        onAccent      = Color(rgb: dark ? 0x0E0D0D : 0xFDFCFC)
        success       = Color(rgb: dark ? 0x34C77B : 0x147F48)
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

struct RatesWidgetView: View {
    let entry: RatesEntry
    let size: WidgetSize

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = WTheme(scheme)
        switch size {
        case .small: SmallRatesLayout(entry: entry, theme: theme)
        case .medium: MediumRatesLayout(entry: entry, theme: theme)
        }
    }
}

// MARK: - Small: BTC + баланс

private struct SmallRatesLayout: View {
    let entry: RatesEntry
    let theme: WTheme

    var body: some View {
        let btc = entry.market?.quote("BTC")
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                BrandMark(theme: theme)
                Text("Биткоин")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textSecondary)
                Spacer(minLength: 0)
            }
            Text(btc.map { WFormat.rub($0.rub) } ?? "–")
                .font(.system(size: 20, weight: .semibold)).monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 6)
            ChangeLabel(quote: btc, theme: theme)
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 6)
            Rectangle().fill(theme.border).frame(height: 0.5)
                .padding(.bottom, 7)

            BalanceBlock(balance: entry.balance, theme: theme, amountSize: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium: баланс слева, BTC и ETH справа

private struct MediumRatesLayout: View {
    let entry: RatesEntry
    let theme: WTheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    BrandMark(theme: theme)
                    Text("Альфа-Ромео")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 8)
                BalanceBlock(balance: entry.balance, theme: theme, amountSize: 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle().fill(theme.border).frame(width: 0.5)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(["BTC", "ETH"], id: \.self) { ticker in
                    CoinRow(ticker: ticker, quote: entry.market?.quote(ticker), theme: theme)
                }
                Spacer(minLength: 0)
                Text(sourceLine)
                    .font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: 134, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The widget's PriceSourceBadge: where the numbers come from, or how old they are.
    private var sourceLine: String {
        guard let market = entry.market else { return "Нет связи с биржей" }
        if entry.marketIsCached { return "Курс на \(WFormat.time(market.fetchedAt, now: entry.date))" }
        return "Binance · курс ЦБ"
    }
}

// MARK: - Pieces

/// The one red accent: a small brand tile.
private struct BrandMark: View {
    let theme: WTheme

    var body: some View {
        Text("А")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.onAccent)
            .frame(width: 16, height: 16)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct ChangeLabel: View {
    let quote: CoinQuote?
    let theme: WTheme

    var body: some View {
        if let quote {
            // DESIGN §6: rises in success, falls in ink (not alarm red).
            Text(WFormat.percent(quote.changePct) + " за сутки")
                .monospacedDigit()
                .foregroundStyle(quote.changePct > 0 ? theme.success : theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.8)
        } else {
            Text("нет данных").foregroundStyle(theme.textTertiary)
        }
    }
}

private struct BalanceBlock: View {
    let balance: BalanceSnapshot?
    let theme: WTheme
    let amountSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Всего в рублях")
                .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            if let balance {
                let parts = WFormat.rubParts(balance.totalRub)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(parts.integer)
                        .font(.system(size: amountSize, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(parts.tail)
                        .font(.system(size: (amountSize * 0.7).rounded(), weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .privacySensitive()
                Text("обновлено \(WFormat.time(balance.updatedAt))")
                    .font(.system(size: 11)).foregroundStyle(theme.textTertiary)
            } else {
                Text("Откройте приложение")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }
}

private struct CoinRow: View {
    let ticker: String
    let quote: CoinQuote?
    let theme: WTheme

    var body: some View {
        HStack(spacing: 8) {
            CoinGlyph(ticker: ticker)
            VStack(alignment: .leading, spacing: 1) {
                Text(quote.map { WFormat.rub($0.rub) } ?? "–")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    Text(ticker).foregroundStyle(theme.textSecondary)
                    if let quote {
                        Text(WFormat.percent(quote.changePct))
                            .monospacedDigit()
                            .foregroundStyle(quote.changePct > 0 ? theme.success : theme.textPrimary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            }
        }
    }
}

/// Real coin colours are the only colour besides the accent (DESIGN §1).
private struct CoinGlyph: View {
    let ticker: String

    var body: some View {
        let (symbol, rgb): (String, UInt32) = ticker == "BTC" ? ("₿", 0xF7931A) : ("Ξ", 0x627EEA)
        Text(symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color(rgb: rgb), in: Circle())
    }
}
