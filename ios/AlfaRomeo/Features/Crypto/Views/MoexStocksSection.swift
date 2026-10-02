import SwiftUI

/// «Биржа» → «Акции» (third segment next to Крипта / ЦФА): TQBR shares, two ОФЗ and gold with real
/// Moscow Exchange quotes from ``MoexFeed`` (MOEX ISS, polled every 15 s while visible). The badge
/// says honestly where the numbers come from: delayed ISS, saved copy or «Демо-котировки».
struct MoexStocksSection: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @State private var feed = MoexFeed.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                MoexSourceBadge(feed: feed)
                Text(feed.sourceNote)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupedSection("Акции") {
                ForEach(MoexInstrument.shares) { row($0) }
            }
            GroupedSection("Облигации федерального займа") {
                ForEach(MoexInstrument.bonds) { row($0) }
            }
            GroupedSection("Драгметаллы") {
                ForEach(MoexInstrument.metals) { row($0) }
            }
        }
        .task { await feed.poll() }
    }

    private func row(_ inst: MoexInstrument) -> some View {
        MoexQuoteRow(instrument: inst, quote: feed.quote(inst.secid)) {
            router.push(CryptoRoute.stockDetail(secid: inst.secid))
        }
    }
}

/// One instrument row: monogram, name + ticker (bonds: yield), last price and day %.
struct MoexQuoteRow: View {
    let instrument: MoexInstrument
    let quote: MoexQuote?
    var onTap: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var subtitle: String {
        switch instrument.kind {
        case .share: return instrument.ticker
        case .bond:
            if let y = quote?.yield { return "доходность \(MoneyFormat.percent(y, minFractionDigits: 2, maxFractionDigits: 2))" }
            return "погашение \(instrument.maturity ?? "")"
        case .metal: return "GLDRUB · \(instrument.unitNote)"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(text: instrument.monogram, size: ListRow.glyphSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(instrument.title)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                if let quote {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(MoneyFormat.fiat(quote.price))
                            .font(BrandFont.bodyM)
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()
                            .contentTransition(reduceMotion ? .identity : .numericText())
                            .animation(reduceMotion ? nil : Motion.snappy, value: quote.price)
                        MoexChangeText(pct: quote.changePct)
                    }
                } else {
                    Text("нет данных").font(BrandFont.subheadline).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }
}

/// Day change «+0,14 %» / «−0,20 %», green / red, neutral at zero.
struct MoexChangeText: View {
    let pct: Double
    var suffix: String = ""
    var font: Font = BrandFont.subheadline

    @Environment(\.theme) private var theme

    var body: some View {
        Text(MoneyFormat.percent(pct, minFractionDigits: 2, maxFractionDigits: 2, sign: .always) + suffix)
            .font(font)
            .foregroundStyle(pct > 0 ? theme.success : pct < 0 ? theme.danger : theme.textSecondary)
            .monospacedDigit()
    }
}

/// Source chip in the ``PriceSourceBadge`` look: green dot for a fresh ISS answer, amber for a saved
/// copy or the demo snapshot.
struct MoexSourceBadge: View {
    var feed: MoexFeed

    @Environment(\.theme) private var theme

    private var healthy: Bool { feed.source == .live }
    private var tint: Color {
        if healthy { return theme.isDark ? theme.success : BrandColors.successInkLight }
        return theme.isDark ? theme.warning : BrandColors.warningInkLight
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(healthy ? theme.success : theme.warning)
                .frame(width: 7, height: 7)
            Text(feed.badgeTitle)
                .font(BrandFont.micro)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Источник котировок: \(feed.badgeTitle)")
    }
}
