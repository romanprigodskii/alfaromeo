import SwiftUI

// MARK: - Section header

/// THE section header (docs/DESIGN.md §3): title2 22 bold, sentence case, left aligned, optional
/// trailing text action («Все») in accent 15 medium. No uppercase letter-spaced labels anywhere.
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(title)
                .font(BrandFont.title2)
                .foregroundStyle(theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Grouped section

/// The default container (docs/DESIGN.md §4): an optional ``SectionHeader`` above a `surface` group
/// with radius 16, no border, and hairline separators between rows inset to the text column.
///
/// Every direct child (a `ForEach` counts as many) becomes one row: it gets 16pt side padding and a
/// separator below it unless it is the last. ``ListRow`` reports its text column, so separators line
/// up under the title; any custom row can do the same with `.groupedRowTextInset(_:)`.
///
/// ```swift
/// GroupedSection("Счета", actionTitle: "Все", action: openAll) {
///     ForEach(accounts) { a in
///         Button { open(a) } label: { ListRow(icon: "rublesign", title: a.title, value: …) }
///             .buttonStyle(.row)
///     }
/// }
/// ```
struct GroupedSection<Content: View>: View {
    var title: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var footer: String?
    /// Overrides the separator inset for every row (measured from the row's leading padding).
    var separatorInset: CGFloat?
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    init(_ title: String? = nil,
         actionTitle: String? = nil,
         action: (() -> Void)? = nil,
         footer: String? = nil,
         separatorInset: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.footer = footer
        self.separatorInset = separatorInset
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            if let title {
                SectionHeader(title, actionTitle: actionTitle, action: action)
            }

            _VariadicView.Tree(GroupedRowsLayout(separatorInset: separatorInset)) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))

            if let footer {
                Text(footer)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Lays the section's children out as rows with inset hairlines between them.
private struct GroupedRowsLayout: _VariadicView_MultiViewRoot {
    var separatorInset: CGFloat?

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastId = children.last?.id
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { child in
                GroupedRow(isLast: child.id == lastId, separatorInset: separatorInset) { child }
            }
        }
    }
}

private struct GroupedRow<Row: View>: View {
    let isLast: Bool
    let separatorInset: CGFloat?
    @ViewBuilder var row: () -> Row

    var body: some View {
        row()
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlayPreferenceValue(GroupedRowTextInsetKey.self, alignment: .bottomLeading) { reported in
                if !isLast {
                    Hairline()
                        .padding(.leading, Spacing.md + (separatorInset ?? reported ?? 0))
                }
            }
    }
}

// MARK: - Separator alignment

/// The x-offset of a row's text column from its leading edge (0 for text-only rows, 48 for a row
/// with a 36pt glyph). Read by ``GroupedSection`` to inset the separator below the row.
struct GroupedRowTextInsetKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if value == nil { value = nextValue() }
    }
}

extension View {
    /// Declares where this row's text column starts (from the row's leading edge), so a
    /// ``GroupedSection`` separator lines up under the text.
    func groupedRowTextInset(_ inset: CGFloat) -> some View {
        preference(key: GroupedRowTextInsetKey.self, value: inset)
    }
}

// MARK: - Hairline

/// A one-pixel `border` line.
struct Hairline: View {
    var axis: Axis = .horizontal
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let px = 1 / max(displayScale, 1)
        Rectangle()
            .fill(theme.border)
            .frame(width: axis == .vertical ? px : nil, height: axis == .horizontal ? px : nil)
            .accessibilityHidden(true)
    }
}

// MARK: - Row press style

/// Press feedback for a tappable row inside a ``GroupedSection``: a `fill` wash, no scale.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowPressBody(configuration: configuration)
    }

    private struct RowPressBody: View {
        let configuration: Configuration
        @Environment(\.theme) private var theme

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .background(
                    theme.fill
                        .opacity(configuration.isPressed ? 1 : 0)
                        .padding(.horizontal, -Spacing.md)
                )
        }
    }
}

extension ButtonStyle where Self == RowButtonStyle {
    /// Row press feedback for ``GroupedSection`` rows.
    static var row: RowButtonStyle { RowButtonStyle() }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.section) {
            GroupedSection("Счета", actionTitle: "Все", action: {}) {
                ListRow(icon: "rublesign", title: "Текущий счёт", subtitle: "RUB", value: "184 200,50 ₽")
                ListRow(icon: "dollarsign", title: "Валютный", subtitle: "USD", value: "1 250 $")
            }
            GroupedSection(footer: "Настройки сохраняются на устройстве.") {
                ListRow(title: "Тема", value: "Светлая", showsChevron: true)
                ListRow(title: "Язык", value: "Русский", showsChevron: true)
            }
        }
        .padding(Spacing.screen)
    }
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
