import SwiftUI

// Management sheets for the card detail screen (§6.3): лимиты, смена дизайна, привязка, PIN,
// Пополнить/Перевести. Each is presented via `.sheet` and reports back through a closure; the store
// owns the actual mutation.

// MARK: - Limits

struct CardLimitsSheet: View {
    let initial: CardLimits
    let onSave: (CardLimits) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var limits: CardLimits

    init(initial: CardLimits, onSave: @escaping (CardLimits) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _limits = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    GroupedSection {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Потрачено в этом месяце").font(BrandFont.subheadline)
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text(MoneyFormat.percent(fraction: limits.monthlyProgress, maxFractionDigits: 0))
                                    .font(BrandFont.subheadline).monospacedDigit()
                                    .foregroundStyle(theme.textPrimary)
                            }
                            AmountText(amount: limits.monthlySpent, size: 22)
                            ProgressBar(value: limits.monthlyProgress)
                        }
                        .padding(.vertical, Spacing.rowVertical + 4)

                        slider(title: "На операцию", value: $limits.perTransaction,
                               range: 5_000...300_000, step: 5_000)
                        slider(title: "В месяц", value: $limits.monthly,
                               range: 10_000...2_000_000, step: 10_000)
                    }

                    GroupedSection("Способы оплаты") {
                        Toggle(isOn: $limits.onlineEnabled) {
                            Text("Онлайн-платежи").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        }
                        .tint(theme.accent)
                        .frame(minHeight: Spacing.rowMinHeight)
                        Toggle(isOn: $limits.contactlessEnabled) {
                            Text("Бесконтактная оплата").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        }
                        .tint(theme.accent)
                        .frame(minHeight: Spacing.rowMinHeight)
                    }

                    PrimaryButton(title: "Сохранить лимиты") { onSave(limits); dismiss() }
                }
                .padding(Spacing.screen)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Лимиты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private func slider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Spacer()
                AmountText(amount: value.wrappedValue, size: 17)
            }
            Slider(value: value, in: range, step: step).tint(theme.accent)
        }
        .padding(.vertical, Spacing.rowVertical)
    }
}

// MARK: - Design picker

struct CardDesignPickerSheet: View {
    let card: CardItem
    let options: [CardDesign]
    let onPick: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String

    init(card: CardItem, options: [CardDesign], onPick: @escaping (String) -> Void) {
        self.card = card
        self.options = options
        self.onPick = onPick
        _selected = State(initialValue: card.designId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    CardFaceView(card: preview(selected))
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity)

                    GroupedSection(separatorInset: 72) {
                        ForEach(options) { design in
                            Button { withAnimation(Motion.snappy) { selected = design.id } } label: {
                                HStack(spacing: Spacing.sm + 4) {
                                    CardFaceView(card: preview(design.id)).frame(width: 60)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(design.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                                        Text(design.blurb).font(BrandFont.subheadline)
                                            .foregroundStyle(theme.textSecondary)
                                    }
                                    Spacer(minLength: Spacing.sm)
                                    if selected == design.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .padding(.vertical, Spacing.sm + 2)
                            }
                            .buttonStyle(.row)
                        }
                    }

                    PrimaryButton(title: "Применить дизайн") { onPick(selected); dismiss() }
                        .disabled(selected == card.designId)
                }
                .padding(Spacing.screen)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Дизайн карты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private func preview(_ designId: String) -> CardItem {
        var c = card; c.designId = designId; return c
    }
}

// MARK: - Rebind (account / crypto asset)

struct CardRebindSheet: View {
    let card: CardItem
    let accounts: [Account]
    let wallets: [CryptoWallet]
    let onPick: (_ accountId: String?, _ asset: String?) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var isCrypto: Bool { card.type == .crypto }

    var body: some View {
        NavigationStack {
            ScrollView {
                GroupedSection(isCrypto ? "Списывать с актива" : "Счёт карты") {
                    if isCrypto {
                        ForEach(wallets) { w in
                            pickRow(glyph: w.asset, title: "\(w.asset) · \(w.chain)",
                                    subtitle: MoneyFormat.amount(w.balance, currency: w.asset),
                                    selected: card.assetLink == w.asset) {
                                onPick(card.accountId, w.asset); dismiss()
                            }
                        }
                    } else {
                        ForEach(accounts) { a in
                            pickRow(glyph: a.currency, title: accountTitle(a),
                                    subtitle: MoneyFormat.fiat(a.balance, currency: MoneyFormat.symbol(for: a.currency)),
                                    selected: card.accountId == a.id) {
                                onPick(a.id, card.assetLink); dismiss()
                            }
                        }
                    }
                }
                .padding(Spacing.screen)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Привязка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private func pickRow(glyph: String, title: String, subtitle: String, selected: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CardPickRow(glyph: glyph, title: title, subtitle: subtitle, selected: selected)
        }
        .buttonStyle(.row)
    }

    private func accountTitle(_ a: Account) -> String {
        switch a.type {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой рубль"
        }
    }
}

// MARK: - PIN

struct CardPinSheet: View {
    let onSave: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirm = ""

    private var valid: Bool { pin.count == 4 && pin == confirm }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Новый PIN из 4 цифр (демо).")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                pinField("Новый PIN", text: $pin)
                pinField("Повторите PIN", text: $confirm)
                if !confirm.isEmpty && pin != confirm {
                    Text("PIN-коды не совпадают").font(BrandFont.footnote).foregroundStyle(theme.danger)
                }
                Spacer()
                PrimaryButton(title: "Сохранить PIN") { onSave(); dismiss() }.disabled(!valid)
            }
            .padding(Spacing.screen)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Смена PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private func pinField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            SecureField("••••", text: text)
                .keyboardType(.numberPad)
                .font(BrandFont.mono(20, weight: .medium))
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .onChange(of: text.wrappedValue) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    text.wrappedValue = String(digits.prefix(4))
                }
        }
    }
}

// MARK: - Quick move (Пополнить / Перевести)

enum MoveKind {
    case topUp, transfer
    var title: String { self == .topUp ? "Пополнить" : "Перевести" }
    var verb: String { self == .topUp ? "Пополнить" : "Перевести" }
    var icon: String { self == .topUp ? "arrow.down.to.line" : "arrow.up.right" }
}

struct QuickMoveSheet: View {
    let kind: MoveKind
    let account: Account
    let onConfirm: (Double) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 0
    @State private var done = false

    private let quickAmounts: [Double] = [1_000, 5_000, 10_000, 25_000]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if done {
                    successView
                } else {
                    Text(kind == .topUp ? "Сумма пополнения" : "Сумма перевода")
                        .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                    AmountText(amount: amount, size: 40)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Spacing.sm)], spacing: Spacing.sm) {
                        ForEach(quickAmounts, id: \.self) { value in
                            Button { withAnimation(Motion.snappy) { amount += value } } label: {
                                Text(MoneyFormat.fiat(value, sign: .always)).font(BrandFont.body(15, weight: .medium))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity).frame(minHeight: 44)
                                    .foregroundStyle(theme.textPrimary)
                                    .background(theme.fill, in: Capsule())
                            }.buttonStyle(PressableButtonStyle())
                        }
                    }

                    HStack {
                        Text(kind == .topUp ? "Счёт зачисления" : "Счёт списания")
                            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text(MoneyFormat.fiat(account.balance, currency: MoneyFormat.symbol(for: account.currency)))
                            .font(BrandFont.subheadline).monospacedDigit()
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.top, Spacing.sm)

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        SecondaryButton(title: "Сброс") { withAnimation(Motion.snappy) { amount = 0 } }
                        PrimaryButton(title: kind.verb) {
                            onConfirm(amount)
                            withAnimation(Motion.smooth) { done = true }
                        }.disabled(amount <= 0)
                    }
                }
            }
            .padding(Spacing.screen)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button(done ? "Готово" : "Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private var successView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light)).foregroundStyle(theme.success)
            Text(kind == .topUp ? "Счёт пополнен" : "Перевод выполнен")
                .font(BrandFont.title1).foregroundStyle(theme.textPrimary)
            AmountText(amount: kind == .topUp ? amount : -amount, size: 22, showsSign: true, colorBySign: true)
            Spacer()
            PrimaryButton(title: "Готово") { dismiss() }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pick row (account / asset)

/// A selectable account or asset row: currency glyph, title, balance, accent checkmark when selected.
/// Shared by the rebind sheet and the order wizard.
struct CardPickRow: View {
    let glyph: String
    let title: String
    let subtitle: String
    let selected: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm + 4) {
            GlyphCircle(currency: glyph)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(subtitle).font(BrandFont.subheadline).monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(48)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
