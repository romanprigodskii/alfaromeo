import SwiftUI

/// A themed segmented control with a sliding accent highlight — used for the feed flow filter
/// (Все / Пополнения / Списания) and the analytics tabs (Расходы / Доходы / Вся аналитика).
///
/// Generic over any `Hashable` value so callers bind their own enum. Honors Reduce Motion (the
/// highlight snaps instead of sliding). Lives in the module rather than the global DS because no
/// segmented control exists there yet and the task is scoped to `Features/History/`.
struct HistorySegmentedControl<Value: Hashable>: View {
    let segments: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(segments, id: \.value) { segment in
                let isSelected = segment.value == selection
                Button {
                    selection = segment.value
                } label: {
                    Text(segment.title)
                        .font(BrandFont.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(theme.accent)
                                    .matchedGeometryEffect(id: "seg", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(theme.elevated, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(theme.border, lineWidth: 1))
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
