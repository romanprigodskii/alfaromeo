import SwiftUI

/// A themed bottom sheet built on native presentation detents + drag indicator.
private struct BottomSheetModifier<SheetBody: View>: ViewModifier {
    @Binding var isPresented: Bool
    var detents: Set<PresentationDetent>
    @ViewBuilder var sheetBody: () -> SheetBody

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetBody()
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.background)
                .environment(\.theme, theme)
        }
    }
}

extension View {
    /// Present `content` as a themed bottom sheet (native detents).
    func bottomSheet<SheetBody: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> SheetBody
    ) -> some View {
        modifier(BottomSheetModifier(isPresented: isPresented, detents: detents, sheetBody: content))
    }
}

#Preview {
    struct BottomSheetPreviewHost: View {
        @State private var shown = true
        var body: some View {
            ZStack {
                Theme.default.background.ignoresSafeArea()
                PrimaryButton(title: "Открыть BottomSheet") { shown = true }
                    .padding(Spacing.lg)
            }
            .bottomSheet(isPresented: $shown) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("BottomSheet").font(BrandFont.title).foregroundStyle(Theme.default.textPrimary)
                    Text("Нативные detents + индикатор перетаскивания, тематический фон.")
                        .font(BrandFont.body()).foregroundStyle(Theme.default.textSecondary)
                    StatusPill(status: .success, text: "Готово")
                }
            }
            .environment(\.theme, .default)
        }
    }
    return BottomSheetPreviewHost()
}
