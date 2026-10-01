import SwiftUI

/// A flat segmented control (docs/DESIGN.md §5: native look, no shadows) for the feed flow filter
/// (Все / Пополнения / Списания) and the analytics tabs (Расходы / Доходы / Вся аналитика).
///
/// Generic over any `Hashable` value so callers bind their own enum. A neutral `fill` track with a
/// `surface` thumb that slides to the selection; honors Reduce Motion (the thumb snaps instead).
struct HistorySegmentedControl<Value: Hashable>: View {
    let segments: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight

    /// Dark surfaces sit below `fill` in luminance, so the thumb lifts with a light ink wash instead.
    private var thumb: Color { theme.isDark ? theme.textPrimary.opacity(0.16) : theme.surface }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.value) { segment in
                let isSelected = segment.value == selection
                Button {
                    selection = segment.value
                } label: {
                    Text(segment.title)
                        .font(BrandFont.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Radius.chip - 1, style: .continuous)
                                    .fill(thumb)
                                    .matchedGeometryEffect(id: "seg", in: highlight)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip + 1, style: .continuous))
        .animation(reduceMotion ? nil : Motion.snappy, value: selection)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    struct Host: View {
        @State private var scope: AnalyticsScope = .expense
        var body: some View {
            HistorySegmentedControl(
                segments: AnalyticsScope.allCases.map { ($0, $0.title) },
                selection: $scope
            )
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.default.background)
            .environment(\.theme, .default)
        }
    }
    return Host()
}
