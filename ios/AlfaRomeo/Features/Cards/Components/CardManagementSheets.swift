import SwiftUI

// Management sheets for the card detail screen (§6.3): лимиты · смена дизайна · привязка · PIN ·
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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Потрачено в этом месяце").font(BrandFont.caption)
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text("\(Int(limits.monthlyProgress * 100))%")
                                    .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                            }
                            ProgressBar(value: limits.monthlyProgress)
                            AmountText(amount: limits.monthlySpent, size: 17)
                        }
                    }

                    slider(title: "Лимит на операцию", value: $limits.perTransaction,
                           range: 5_000...300_000, step: 5_000)
                    slider(title: "Месячный лимит", value: $limits.monthly,
                           range: 10_000...2_000_000, step: 10_000)

                    SurfaceCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            Toggle(isOn: $limits.onlineEnabled) {
                                Label("Онлайн-платежи", systemImage: "globe").font(BrandFont.bodyM)
                                    .foregroundStyle(theme.textPrimary)
                            }.tint(theme.accent).padding(.vertical, Spacing.xs)
                            Divider().overlay(theme.border)
                            Toggle(isOn: $limits.contactlessEnabled) {
                                Label("Бесконтакт (NFC)", systemImage: "wave.3.right").font(BrandFont.bodyM)
                                    .foregroundStyle(theme.textPrimary)
                            }.tint(theme.accent).padding(.vertical, Spacing.xs)
                        }
                    }

                    PrimaryButton(title: "Сохранить лимиты") { onSave(limits); dismiss() }
                }
                .padding(Spacing.lg)
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
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Spacer()
                    AmountText(amount: value.wrappedValue, size: 17)
                }
                Slider(value: value, in: range, step: step).tint(theme.accent)
            }
        }
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
                VStack(spacing: Spacing.md) {
                    ForEach(options) { design in
                        Button { withAnimation(Motion.snappy) { selected = design.id } } label: {
                            VStack(spacing: Spacing.sm) {
                                CardFaceView(card: preview(design.id))
                                    .frame(maxWidth: 240)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(design.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                                        Text(design.blurb).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: selected == design.id ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20)).foregroundStyle(selected == design.id ? theme.accent : theme.border)
                                }
                            }
                            .padding(Spacing.md)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .stroke(selected == design.id ? theme.accent : theme.border,
                                        lineWidth: selected == design.id ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }

                    PrimaryButton(title: "Применить дизайн") { onPick(selected); dismiss() }
                        .disabled(selected == card.designId)
                }
                .padding(Spacing.lg)
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
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(isCrypto ? "Списывать с крипто-актива" : "Привязать к счёту")
                        .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                    SurfaceCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            if isCrypto {
                                ForEach(Array(wallets.enumerated()), id: \.element.id) { i, w in
                                    pickRow(title: "\(w.asset) · \(w.chain)",
                                            subtitle: "\(w.balance) \(w.asset)",
                                            selected: card.assetLink == w.asset) {
                                        onPick(card.accountId, w.asset); dismiss()
                                    }
                                    if i < wallets.count - 1 { Divider().overlay(theme.border) }
                                }
                            } else {
                                ForEach(Array(accounts.enumerated()), id: \.element.id) { i, a in
                                    pickRow(title: accountTitle(a),
                                            subtitle: "\(Int(a.balance)) \(a.currency)",
                                            selected: card.accountId == a.id) {
                                        onPick(a.id, card.assetLink); dismiss()
                                    }
                                    if i < accounts.count - 1 { Divider().overlay(theme.border) }
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Привязка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }.tint(theme.accent)
            } }
        }
    }

    private func pickRow(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: selected ? "checkmark.circle.fill" : "circle",
                    iconTint: selected ? theme.accent : theme.textSecondary,
                    title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Задайте новый PIN из 4 цифр (демо).")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                pinField("Новый PIN", text: $pin)
                pinField("Повторите PIN", text: $confirm)
                if !confirm.isEmpty && pin != confirm {
                    Text("PIN-коды не совпадают").font(BrandFont.caption).foregroundStyle(theme.danger)
                }
                Spacer()
                PrimaryButton(title: "Сохранить PIN") { onSave(); dismiss() }.disabled(!valid)
            }
            .padding(Spacing.lg)
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
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            SecureField("••••", text: text)
                .keyboardType(.numberPad)
                .font(BrandFont.mono(20, weight: .medium))
                .padding(Spacing.md)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if done {
                    successView
                } else {
                    Text(kind == .topUp ? "Сумма пополнения" : "Сумма перевода")
                        .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                    AmountText(amount: amount, size: 34)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Spacing.sm)], spacing: Spacing.sm) {
                        ForEach(quickAmounts, id: \.self) { value in
                            Button { withAnimation(Motion.snappy) { amount += value } } label: {
                                Text("+\(Int(value)) ₽").font(BrandFont.callout.weight(.semibold))
                                    .frame(maxWidth: .infinity).frame(minHeight: 44)
                                    .foregroundStyle(theme.textPrimary)
                                    .background(theme.elevated, in: Capsule())
                            }.buttonStyle(PressableButtonStyle())
                        }
                    }

                    HStack {
                        Text("Счёт списания/зачисления").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text("\(Int(account.balance)) \(account.currency)").font(BrandFont.callout)
                            .foregroundStyle(theme.textPrimary)
                    }

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        SecondaryButton(title: "Сброс") { withAnimation(Motion.snappy) { amount = 0 } }
                        PrimaryButton(title: kind.verb, icon: kind.icon) {
                            onConfirm(amount)
                            withAnimation(Motion.smooth) { done = true }
                        }.disabled(amount <= 0)
                    }
                }
            }
            .padding(Spacing.lg)
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundStyle(theme.success)
            Text(kind == .topUp ? "Счёт пополнен" : "Перевод выполнен")
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
            AmountText(amount: kind == .topUp ? amount : -amount, size: 24, showsSign: true, colorBySign: true)
            Spacer()
            PrimaryButton(title: "Готово") { dismiss() }
        }
        .frame(maxWidth: .infinity)
    }
}
