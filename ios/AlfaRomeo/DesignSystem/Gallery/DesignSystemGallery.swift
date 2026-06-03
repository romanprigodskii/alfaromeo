import SwiftUI

// MARK: - Gallery entry

/// Interactive gallery of every DesignSystem token and component, with live theme switching
/// (personal / business / child) and a light/dark toggle. Light is the primary scheme; dark is
/// supported. Preview-only — not part of any feature flow.
struct DesignSystemGallery: View {
    @State private var profile: GalleryProfile
    @State private var scheme: ColorScheme

    init(profileType: ProfileType? = nil, scheme: ColorScheme = .light) {
        _profile = State(initialValue: GalleryProfile(profileType: profileType))
        _scheme = State(initialValue: scheme)
    }

    var body: some View {
        ThemeProvider(profileType: profile.profileType, scheme: scheme) {
            GalleryScreen(profile: $profile, scheme: $scheme)
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
    @Environment(\.theme) private var theme
    @State private var sheetShown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ControlsCard(profile: $profile, scheme: $scheme, sheetShown: $sheetShown)
                GallerySection(title: "Цвет") { ColorTokens() }
                GallerySection(title: "Типографика") { TypographySamples() }
                GallerySection(title: "Кнопки") { ButtonsDemo(sheetShown: $sheetShown) }
                GallerySection(title: "Поверхности и строки") { SurfacesDemo() }
                GallerySection(title: "Статусы и прогресс") { StatusDemo() }
                GallerySection(title: "Аватар · Бейдж · Сумма") { MiscDemo() }
            }
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .bottomSheet(isPresented: $sheetShown) { SheetDemo() }
    }
}

// MARK: - Section wrapper

private struct GallerySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(BrandFont.micro)
                .tracking(2)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }
}

// MARK: - Controls

private struct ControlsCard: View {
    @Binding var profile: GalleryProfile
    @Binding var scheme: ColorScheme
    @Binding var sheetShown: Bool
    @Environment(\.theme) private var theme

    private var schemeBinding: Binding<Int> {
        Binding(get: { scheme == .dark ? 0 : 1 },
                set: { scheme = $0 == 0 ? .dark : .light })
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("DesignSystem").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Badge(kind: .text("Фаза 0"), tint: theme.accent)
                }
                Picker("Профиль", selection: $profile) {
                    ForEach(GalleryProfile.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Тема", selection: schemeBinding) {
                    Text("Тёмная").tag(0)
                    Text("Светлая").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Colors

private struct ColorTokens: View {
    @Environment(\.theme) private var theme

    private var swatches: [(String, Color)] {
        [("background", theme.background), ("surface", theme.surface), ("elevated", theme.elevated),
         ("border", theme.border), ("textPrimary", theme.textPrimary), ("textSecondary", theme.textSecondary),
         ("accent", theme.accent), ("onAccent", theme.onAccent),
         ("success", theme.success), ("danger", theme.danger), ("warning", theme.warning)]
    }

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(swatches, id: \.0) { Swatch(name: $0.0, color: $0.1) }
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(theme.cryptoGradient)
                    .frame(height: 56)
                Text("accentCrypto · холодный градиент крипто/AI")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }
}

private struct Swatch: View {
    let name: String
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(color)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
            Text(name).font(BrandFont.micro).foregroundStyle(theme.textSecondary).lineLimit(1)
        }
    }
}

// MARK: - Typography

private struct TypographySamples: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sample("display", BrandFont.displayL, "Альфа-Ромео")
            sample("title", BrandFont.title, "Заголовок раздела")
            sample("body", BrandFont.bodyM, "Нейтральный текст интерфейса")
            sample("mono", BrandFont.mono(17), "1 234 567,89 ₽")
        }
    }

    private func sample(_ label: String, _ font: Font, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Text(text).font(font).foregroundStyle(theme.textPrimary)
        }
    }
}

// MARK: - Buttons

private struct ButtonsDemo: View {
    @Binding var sheetShown: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Перевести", icon: "arrow.up.right") {}
            PrimaryButton(title: "Загрузка…", isLoading: true) {}
            SecondaryButton(title: "Открыть BottomSheet", icon: "chevron.up.circle") { sheetShown = true }
            SecondaryButton(title: "Недоступно") {}.disabled(true)
        }
    }
}

// MARK: - Surfaces & rows

private struct SurfacesDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.md) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("SurfaceCard").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("Базовый контейнер поверхности с бордером.")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ListRow(icon: "creditcard", title: "Карта ··4921", subtitle: "Виртуальная",
                            value: "12 400 ₽", showsChevron: true)
                    Divider().overlay(theme.border)
                    ListRow(icon: "bitcoinsign", iconTint: theme.accentCrypto.first,
                            title: "Криптокошелёк", subtitle: "BTC", value: "0.142", showsChevron: true)
                    Divider().overlay(theme.border)
                    ListRow(icon: "antenna.radiowaves.left.and.right", title: "Ромео Mobile",
                            subtitle: "Пакет M", value: "24 ГБ", showsChevron: true)
                }
            }
        }
    }
}

// MARK: - Statuses & progress

private struct StatusDemo: View {
    @Environment(\.theme) private var theme
    @State private var progress: Double = 0.62

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                StatusPill(status: .processing)
                StatusPill(status: .success)
                StatusPill(status: .declined)
            }
            HStack(spacing: Spacing.sm) {
                StatusPill(status: .pending)
                StatusPill(status: .warning)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Цель: накопить на отпуск").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                ProgressBar(value: progress)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Лимит крипты (Pro)").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                ProgressBar(value: 0.35, useCryptoGradient: true)
            }
            Slider(value: $progress, in: 0...1).tint(theme.accent)
        }
    }
}

// MARK: - Avatar / Badge / Amount

private struct MiscDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Avatar(initials: "АР")
                Avatar(systemImage: "person.fill")
                Avatar(initials: "PRO", ringColor: theme.accent)
                ZStack(alignment: .topTrailing) {
                    Avatar(systemImage: "bell.fill")
                    Badge(kind: .count(3)).offset(x: 4, y: -4)
                }
            }
            HStack(spacing: Spacing.sm) {
                Badge(kind: .text("PRO"), tint: theme.accent)
                Badge(kind: .text("CRYPTO"), tint: theme.accentCrypto.first)
                Badge(kind: .count(12))
                Badge(kind: .dot, tint: theme.success)
            }
            HStack(spacing: Spacing.lg) {
                AmountText(amount: 1234567.89)
                AmountText(amount: -2400, size: 20, showsSign: true, colorBySign: true)
            }
            AmountText(amount: 15890.5, currency: "USDT", size: 22)
        }
    }
}

// MARK: - Sheet content

private struct SheetDemo: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("BottomSheet").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text("Нативные detents + индикатор перетаскивания, тематический фон.")
                .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
            StatusPill(status: .success, text: "Готово")
            PrimaryButton(title: "Понятно") {}
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews (light = primary; + dark; + profile contexts)

#Preview("Светлая · Личный") {
    DesignSystemGallery(profileType: .personal, scheme: .light)
}

#Preview("Тёмная · Личный") {
    DesignSystemGallery(profileType: .personal, scheme: .dark)
}

#Preview("Светлая · Бизнес") {
    DesignSystemGallery(profileType: .business, scheme: .light)
}

#Preview("Светлая · Детский") {
    DesignSystemGallery(profileType: .child, scheme: .light)
}
