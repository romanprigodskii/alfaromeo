import SwiftUI

// MARK: - Gallery entry

/// Living reference for docs/DESIGN.md: every token and component, with live switching of the
/// profile context and light / dark. Preview and `-ARShot gallery` only, not part of any flow.
struct DesignSystemGallery: View {
    /// Gallery sections a screenshot can open at.
    enum Anchor: String, Sendable { case rows, cards, numbers, buttons, status, type, color }

    @State private var profile: GalleryProfile
    @State private var scheme: ColorScheme
    private let anchor: Anchor?

    init(profileType: ProfileType? = nil, scheme: ColorScheme = .light, scrollTo anchor: Anchor? = nil) {
        _profile = State(initialValue: GalleryProfile(profileType: profileType))
        _scheme = State(initialValue: scheme)
        self.anchor = anchor
    }

    var body: some View {
        ThemeProvider(profileType: profile.profileType, scheme: scheme) {
            GalleryScreen(profile: $profile, scheme: $scheme, anchor: anchor)
        }
    }
}

// MARK: - Profile option

private enum GalleryProfile: String, CaseIterable, Identifiable {
    case personal, business, child, joint

    init(profileType: ProfileType?) {
        switch profileType {
        case .business: self = .business
        case .child:    self = .child
        case .joint:    self = .joint
        default:        self = .personal
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: return "Личный"
        case .business: return "Бизнес"
        case .child:    return "Детский"
        case .joint:    return "Семейный"
        }
    }

    var profileType: ProfileType {
        switch self {
        case .personal: return .personal
        case .business: return .business
        case .child:    return .child
        case .joint:    return .joint
        }
    }
}

// MARK: - Screen

private struct GalleryScreen: View {
    @Binding var profile: GalleryProfile
    @Binding var scheme: ColorScheme
    let anchor: DesignSystemGallery.Anchor?
    @Environment(\.theme) private var theme
    @State private var sheetShown = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    Controls(profile: $profile, scheme: $scheme)
                    HeroDemo()
                    QuickActionsDemo()
                    RowsDemo().id(DesignSystemGallery.Anchor.rows)
                    CardArtDemo().id(DesignSystemGallery.Anchor.cards)
                    NumbersDemo().id(DesignSystemGallery.Anchor.numbers)
                    ButtonsDemo(sheetShown: $sheetShown).id(DesignSystemGallery.Anchor.buttons)
                    StatusDemo().id(DesignSystemGallery.Anchor.status)
                    TypographyDemo().id(DesignSystemGallery.Anchor.type)
                    ColorDemo().id(DesignSystemGallery.Anchor.color)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            }
            .task {
                guard let anchor else { return }
                try? await Task.sleep(for: .milliseconds(300))
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .bottomSheet(isPresented: $sheetShown) { SheetDemo() }
    }
}

// MARK: - Controls

private struct Controls: View {
    @Binding var profile: GalleryProfile
    @Binding var scheme: ColorScheme
    @Environment(\.theme) private var theme

    private var schemeBinding: Binding<Int> {
        Binding(get: { scheme == .dark ? 1 : 0 },
                set: { scheme = $0 == 1 ? .dark : .light })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Дизайн-система")
                .font(BrandFont.largeTitle)
                .foregroundStyle(theme.textPrimary)
            Picker("Профиль", selection: $profile) {
                ForEach(GalleryProfile.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Тема", selection: schemeBinding) {
                Text("Светлая").tag(0)
                Text("Тёмная").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Hero balance

private struct HeroDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Все счета")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
            AmountText(amount: 1_119_200.5, size: 40, splitsKopecks: true)
            Text(MoneyFormat.signed(12_400) + " за месяц")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Quick actions

private struct QuickActionsDemo: View {
    var body: some View {
        QuickActionRow {
            QuickActionButton("Пополнить", systemImage: "plus") {}
            QuickActionButton("Перевести", systemImage: "arrow.up.right") {}
            QuickActionButton("Обмен", systemImage: "arrow.left.arrow.right") {}
            QuickActionButton("Оплатить", systemImage: "qrcode") {}
        }
    }
}

// MARK: - Rows

private struct RowsDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            GroupedSection("Счета", actionTitle: "Все", action: {}) {
                Button {} label: {
                    HStack(spacing: ListRow.glyphSpacing) {
                        GlyphCircle(currency: "RUB")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Текущий счёт").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            Text("•• 4921").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        }
                        Spacer(minLength: Spacing.sm)
                        AmountText(amount: 184_200.5, size: 17)
                    }
                    .padding(.vertical, Spacing.sm)
                    .frame(minHeight: Spacing.rowMinHeightTwoLine)
                    .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
                }
                .buttonStyle(.row)
                ListRow(icon: "dollarsign", title: "Валютный", subtitle: "USD", value: MoneyFormat.fiat(1250, currency: "USD"))
                ListRow(icon: "banknote", title: "Накопительный", subtitle: MoneyFormat.percent(16) + " годовых",
                        value: MoneyFormat.fiat(420_000))
            }

            GroupedSection("Операции") {
                operation("Пятёрочка", "Продукты, 14:20", -1240.5, "cart")
                operation("Зарплата", "Поступление, 09:00", 12400, "arrow.down")
                operation("Steam", "Отклонено", -899, "gamecontroller")
            }

            GroupedSection(footer: "Настройки сохраняются на устройстве.") {
                ListRow(icon: "lock", title: "Безопасность", subtitle: "Face ID, PIN, устройства", showsChevron: true)
                ListRow(icon: "bell", title: "Уведомления", showsChevron: true)
                ListRow(title: "Тема", value: "Светлая", showsChevron: true)
                ListRow(icon: "rectangle.portrait.and.arrow.right", iconTint: theme.danger, title: "Выйти")
            }

            GroupedSection("Загрузка") {
                SkeletonRow()
                SkeletonRow(showsSubtitle: false)
            }
        }
    }

    private func operation(_ title: String, _ subtitle: String, _ amount: Double, _ icon: String) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            AmountText(amount: amount, size: 17, showsSign: true, colorBySign: true)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}

// MARK: - Card art

private struct CardArtDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Карты", actionTitle: "Все", action: {})
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm + 4) {
                    CardArt(last4: "4921", label: "Виртуальная", width: 260)
                    CardArt(last4: "0042", label: "Бизнес", style: .graphite, width: 260)
                    CardArt(last4: "7710", style: .ink, width: 260, isFrozen: true)
                }
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Numbers

private struct NumbersDemo: View {
    var body: some View {
        GroupedSection("Числа", footer: "MoneyFormat: NBSP-группы, десятичная запятая, минус U+2212.") {
            ListRow(title: "Фиат", value: MoneyFormat.fiat(184_200.5))
            ListRow(title: "Целое", value: MoneyFormat.fiat(12_400))
            ListRow(title: "Со знаком", value: MoneyFormat.signed(-1240.5))
            ListRow(title: "Процент", value: MoneyFormat.percent(-0.74))
            ListRow(title: "Ставка", value: MoneyFormat.percent(19.9))
            ListRow(title: "Крипта", value: MoneyFormat.crypto(0.142300, symbol: "BTC"))
            ListRow(title: "Компактно", value: MoneyFormat.compact(2_200_000))
        }
    }
}

// MARK: - Buttons

private struct ButtonsDemo: View {
    @Binding var sheetShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Кнопки")
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Перевести") {}
                PrimaryButton(title: "Подтвердить", icon: "faceid") {}
                SecondaryButton(title: "Открыть шторку") { sheetShown = true }
                PrimaryButton(title: "Недоступно") {}.disabled(true)
                TertiaryButton("Подробнее") {}
            }
        }
    }
}

// MARK: - Statuses & progress

private struct StatusDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Статусы")
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        StatusPill(status: .success)
                        StatusPill(status: .declined)
                        StatusPill(status: .pending)
                    }
                    HStack(spacing: Spacing.sm) {
                        StatusPill(status: .processing)
                        Badge(kind: .text("Pro"), tint: theme.accent)
                        Badge(kind: .text("Live"), tint: theme.success)
                        Badge(kind: .count(3))
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Цель: отпуск").font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text(MoneyFormat.percent(62)).font(BrandFont.subheadline).monospacedDigit().foregroundStyle(theme.textSecondary)
                        }
                        ProgressBar(value: 0.62)
                    }
                    HStack(spacing: Spacing.md) {
                        Avatar(initials: "АР")
                        Avatar(systemImage: "person")
                        Avatar(initials: "ИП", ringColor: theme.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Typography

private struct TypographyDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection("Типографика") {
            sample("largeTitle 34", BrandFont.largeTitle, "Главная")
            sample("title1 28", BrandFont.title1, "Перевод выполнен")
            sample("title2 22", BrandFont.title2, "Заголовок раздела")
            sample("headline 17", BrandFont.headline, "Текущий счёт")
            sample("body 17", BrandFont.bodyM, "Строка списка")
            sample("subheadline 15", BrandFont.subheadline, "Подзаголовок, метаданные")
            sample("footnote 13", BrandFont.footnote, "Сноска, время, юридический текст")
            sample("caption 12", BrandFont.micro, "Бейдж, ось графика")
            sample("code 15", BrandFont.code(15), "40817 810 0 0000 1234567")
        }
    }

    private func sample(_ label: String, _ font: Font, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Text(text).font(font).foregroundStyle(theme.textPrimary)
        }
        .padding(.vertical, Spacing.sm + 2)
    }
}

// MARK: - Colors

private struct ColorDemo: View {
    @Environment(\.theme) private var theme

    private var swatches: [(String, Color)] {
        [("background", theme.background), ("surface", theme.surface), ("elevated", theme.elevated),
         ("fill", theme.fill), ("border", theme.border), ("textPrimary", theme.textPrimary),
         ("textSecondary", theme.textSecondary), ("textTertiary", theme.textTertiary),
         ("accent", theme.accent), ("success", theme.success), ("danger", theme.danger),
         ("warning", theme.warning)]
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Цвет")
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .fill(color)
                            .frame(height: 40)
                            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                .strokeBorder(theme.border, lineWidth: 0.5))
                        Text(name).font(BrandFont.micro).foregroundStyle(theme.textSecondary).lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Sheet content

private struct SheetDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Шторка").font(BrandFont.title1).foregroundStyle(theme.textPrimary)
            Text("Нативные detents, индикатор перетаскивания, фон темы.")
                .font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            StatusPill(status: .success, text: "Готово")
            Spacer(minLength: 0)
            PrimaryButton(title: "Понятно") {}
        }
    }
}

// MARK: - Previews

#Preview("Светлая, личный") {
    DesignSystemGallery(profileType: .personal, scheme: .light)
}

#Preview("Тёмная, личный") {
    DesignSystemGallery(profileType: .personal, scheme: .dark)
}

#Preview("Светлая, бизнес") {
    DesignSystemGallery(profileType: .business, scheme: .light)
}
