# Альфа-Ромео — design system («чётко»)

Why this exists: the owner's verdict on the previous UI was «выглядит гптшно». The diagnosis and
the rules below replace that look with a precise, restrained banking UI. Read `PRODUCT.md` first.
Code lives in `ios/AlfaRomeo/DesignSystem/`; UI reads semantic tokens via `@Environment(\.theme)`.

## 1. Diagnosis: what made it look AI-generated
| Tell | Where it showed up | Rule that replaces it |
|---|---|---|
| Sparkle ✨ icons, gradient-bordered "AI insight" banner | Home, Credit «Почему такая сумма?», Copilot entry points | §7 AI without sparkles |
| Blue→cyan gradients, gradient circle buttons | Crypto hero, quick actions, offer cards | §2 one accent, no decorative gradients |
| Pastel tinted icon tile on every row (accent @14% in a rounded square) | ListRow everywhere | §5 rows: monochrome glyphs or meaningful avatars |
| Everything in a white rounded card with a hairline + nested cards | All hubs | §4 grouped lists, no nesting |
| Heavy (900) display titles, monospaced numbers, letter-spaced CAPS section labels mixed with bold section titles | Credit, Crypto, Payments | §3 one family, one section-header style |
| Broken number format «184 200.5 ₽», «26.0%», dots for decimals | Everywhere | §6 Russian number format |
| Glossy red card with red glow shadow and fake gold chip | Home cards | §5 card art |
| Copy: em-dash taglines, «·» chains, slogans in subtitles, «Главный» | Everywhere | §8 copy |

## 2. Colour (strategy: Restrained)
Tinted neutrals (a hair of warmth toward the brand red) + ONE accent. Never pure `#000` / `#FFF`
for surfaces or text.

Light (primary):
| token | hex | use |
|---|---|---|
| background | `#F3F2F1` | screen background |
| surface | `#FDFCFC` | grouped lists, sheets |
| elevated | `#F8F7F6` | inputs, nested controls on surface |
| fill | `#ECEAE8` | neutral control background (secondary button, quick-action circle, glyph circle) |
| border | `#E6E3E1` | hairlines (0.5pt / 1px) |
| textPrimary | `#141213` | ink |
| textSecondary | `#6E6A69` | labels, metadata (≥4.5:1 on background) |
| textTertiary | `#A39E9C` | placeholders, disabled |
| accent (personal) | `#D3140F` | primary buttons, selection, links. Max ~10% of a screen |

Dark: background `#0E0D0D`, surface `#1A1818`, elevated `#232120`, fill `#2A2726`,
border `#2E2B2A`, textPrimary `#F4F2F1`, textSecondary `#9C9795`, textTertiary `#6A6563`,
accent `#F0302A`.

Profile contexts keep their own accent (business graphite, child violet, joint teal) and business
keeps its cool graphite base. Status colours (success / danger / warning) are for state and signed
amounts only, never decoration.

**Crypto has no special colour.** The blue→cyan "cold gradient" is retired. Crypto screens use the
same neutrals + accent; colour comes only from real coin logos (BTC orange, ETH, TON, USDT…).

Gradients: none, except an extremely subtle (≤4% luminance) vertical shade on bank card art.
Shadows: none on in-flow content. Only floating elements (bottom sheets, the copilot button,
a dragged card) get one soft shadow: `black @ 8%, radius 16, y 4`. No coloured glows, ever.

## 3. Typography
One family: SF Pro (system). No display/body pairing, no `.heavy`/`.black` weights.
Monospace ONLY for card numbers, crypto addresses, requisites (ИНН, БИК, счёт).
All numbers use tabular figures (`.monospacedDigit()`).

| role | size / weight | use |
|---|---|---|
| largeTitle | 34 bold | screen title (nav large title) |
| hero amount | 40 semibold, kopecks 26 semibold textSecondary | the one main balance per screen |
| title1 | 28 bold | rare: sheet titles, result screens |
| title2 (section) | 22 bold | THE section header style (sentence case) |
| headline | 17 semibold | row titles that need emphasis, buttons |
| body | 17 regular | row titles, text |
| callout | 16 regular | secondary row text |
| subheadline | 15 regular | row subtitles, metadata |
| footnote | 13 regular | captions, legal, timestamps |
| caption | 12 medium | badges, chart axes |

Section headers: ONE style — `title2` 22 bold, sentence case, left aligned, optional trailing
text action («Все») in accent 15 medium. No letter-spaced UPPERCASE labels anywhere.

## 4. Layout & containers
- Side margins 16. Section spacing 28–32. Row vertical padding 12, min row height 52 (60 with subtitle).
- Default container = **grouped list section**: `surface` background, radius 16 (continuous), no
  border on light (surface vs background contrast is enough), hairline separators inset to the
  text column. This is `GroupedSection` in the design system.
- A standalone card is allowed only for a genuinely distinct object (a bank card, a chart, a
  single primary summary). Never nest cards. Never wrap a single row in its own card.
- No identical grids of icon+title+subtitle tiles. Use a list, or a horizontal row of quick
  actions (§5).
- Radii: card/section 16, button 14, input 12, chip 8, avatar/glyph circle = full.

## 5. Components
- **Row** (`ListRow`): leading glyph is a monochrome SF Symbol (20pt, textPrimary) in a 36pt
  `fill` circle, or a real avatar/logo/currency glyph (₽ $ € ₮ in a fill circle). No tinted
  pastel tiles. Title body 17, subtitle subheadline 15 textSecondary, trailing value 17
  tabular, chevron 13 semibold textTertiary.
- **Quick actions** (Пополнить / Перевести / Обмен…): 56pt `fill` circles, ink glyph 22pt,
  label footnote 13 below. No gradient circles, no accent fills (the accent is for the one primary CTA).
- **Primary button**: accent fill, height 52, radius 14, headline 17 semibold, onAccent text.
  Leading arrow icons are removed. One primary button per screen.
- **Secondary button**: `fill` background, ink text. **Tertiary**: plain accent text.
- **Segmented control**: native `Picker(.segmented)` look or the same flat style; no shadows.
- **Badge / status pill**: caption 12 medium, radius 8, tinted background only for semantic state
  (успех / ошибка / ожидание / live).
- **Bank card art**: flat accent (personal) or graphite (business), ≤4% vertical shade, radius 14,
  aspect 1.586. Content: bank wordmark (footnote semibold), last 4 in mono, network mark. No fake
  chip, no NFC waves, no glow shadow.
- **Charts**: one series colour = textPrimary or accent; gridlines border; axis labels caption.
- **Empty / loading**: skeleton rows in `fill`, not spinners in the middle of content.

## 6. Numbers (Russian format)
- Group with NBSP (U+00A0), decimal comma: `1 119 200,50 ₽`. NBSP before the currency sign.
- Fiat: 0 decimals if the value is whole, otherwise exactly 2 (never `184 200,5`).
- Hero balance: integer part at hero size, `,50` at the smaller kopecks size in textSecondary.
- Percent: `−0,74 %` with U+2212 minus and NBSP before `%`; rates `26 %` / `19,9 %`.
- Crypto qty: up to 8 significant decimals, trailing zeros trimmed, comma: `0,1423 BTC`.
- Signed amounts: `+12 400 ₽` success colour, `−1 240,50 ₽` textPrimary (debits are normal life,
  not errors; reserve danger for declines/failures).
- Use the central formatter (`MoneyFormat`) in the design system; no ad-hoc `String(format:)`.

## 7. AI without sparkles
- No `sparkles` / `wand` / magic icons. The copilot glyph is a plain monochrome symbol
  (`text.bubble` or a small «AI» monogram) at the same weight as other glyphs.
- AI insights are a normal row or a one-line text with a trailing «Спросить» link, never a
  gradient-bordered banner.
- AI answers read like a calm specialist: short, factual, numbers formatted per §6.

## 8. Copy (Russian)
- No em dashes (—) or `--` in UI copy. Use a comma, colon, period, or a new line.
- No `·` chains longer than two items; prefer one fact.
- Titles are nouns («Главная», «Платежи», «Кредит наличными»). Subtitles carry data (balance,
  date, count, status), not slogans («Деньги на счёт за пару минут» → delete).
- Sentence case everywhere. No exclamation marks.

## 9. Motion
150–250 ms, ease-out. Motion only conveys state (selection, value change via
`.contentTransition(.numericText())`, sheet presentation). No bounces, no shimmer on static
content, no orchestrated entrances. Respect Reduce Motion.

## 10. Implementation map (`ios/AlfaRomeo/DesignSystem/`)
Feature code adopts these; it does not re-implement them.

Tokens
- `theme.background / surface / elevated / fill / border`, `theme.textPrimary / textSecondary / textTertiary`,
  `theme.accent / onAccent`, `theme.success / danger / warning`, `theme.statusInk(_:)` (status hue as text on
  its own tint). `theme.accentCrypto` / `cryptoGradient` still compile but are retired: do not use.
- Type (`BrandFont`): `largeTitle` 34 bold, `title1` 28 bold, `title2` 22 bold (section header), `headline` 17 semibold,
  `bodyM` 17, `callout` 16, `subheadline` 15, `footnote` 13, `micro` 12 medium (the caption role), `heroAmount` 40 /
  `heroKopecks` 26 semibold. Legacy names map onto this scale: `displayL` = largeTitle, `title` = title2,
  `caption` = footnote 13, `displayXL` = heroAmount. Weights are capped at bold (no heavy / black).
- Numbers: `BrandFont.mono(_:)` now means SF Pro with tabular figures (it used to be SF Mono). True monospace is
  `BrandFont.code(_:)`, only for card numbers, crypto addresses and requisites.
- Radius: `Radius.card` / `section` 16, `button` 14, `input` 12, `chip` 8. Spacing: `Spacing.screen` 16,
  `Spacing.section` 28, `Spacing.rowMinHeight` 52 / `rowMinHeightTwoLine` 60.
- Motion: `Motion.snappy` (180 ms) / `smooth` (250 ms) are ease-out curves; `bouncy` is an alias of `smooth`.

Components
- `GroupedSection(_ title:, actionTitle:, action:, footer:, separatorInset:) { rows }`: the default container.
  Each direct child is a row (16pt side padding, inset hairline below). `ListRow` aligns the hairline to its text;
  custom rows call `.groupedRowTextInset(48)` (glyph rows) or nothing (text rows). Tap feedback: `.buttonStyle(.row)`.
- `SectionHeader(_ title:, actionTitle:, action:)`, `ListRow(icon:iconTint:title:subtitle:value:showsChevron:)`
  (monochrome; only a `theme.danger` tint is honoured), `GlyphCircle(systemImage:)` / `(text:)` / `(currency:)`
  (draws the outline form of a symbol: `lock.shield.fill` → `lock.shield`, `rublesign.circle.fill` → `rublesign`),
  `QuickActionButton(_:systemImage:action:)` in a `QuickActionRow`, `PrimaryButton` / `SecondaryButton` /
  `TertiaryButton` (text only; the `icon` argument is ignored except `faceid`), `Badge`, `StatusPill`,
  `ProgressBar`, `CardArt(last4:label:style:width:)` / `CardArt(card:)`, `SkeletonRow`, `Hairline`.
- `AmountText(amount:currency:size:showsSign:colorBySign:splitsKopecks:)` formats through `MoneyFormat`;
  `splitsKopecks: true` is the hero style. `colorBySign` colours credits only.
- `MoneyFormat.fiat / signed / amount / crypto / number / integer / percent / percent(fraction:) / compact / parts /
  symbol(for:)`: every on-screen number goes through it (crypto: up to 8 fraction digits, zeros trimmed).
- `SurfaceCard` is a standalone surface (radius 16, no border). Legacy `SurfaceCard(padding: Spacing.sm)` list
  wrappers get 12pt side / 4pt vertical insets as a bridge; screens move their lists to `GroupedSection`.
- `DesignSystemGallery` (`-ARShot gallery`, `galleryDark`, `galleryBusiness`, `galleryNumbers`, `galleryButtons`,
  `galleryType`, `galleryCards`) is the living reference.
