import SwiftUI

/// A themed placeholder destination for a not-yet-built route (§9). Feature modules replace a route's
/// `destination` with a real screen; until then this proves the section's `.navigationDestination`
/// resolves end-to-end. Owns its own inline navigation title.
struct RouteStubScreen: View {
    let title: String
    var note: String = "Экран соберёт следующий промпт фазы."

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "hammer")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(title)
                .font(BrandFont.title)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(note)
                .font(BrandFont.body())
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RouteStubScreen(title: "Деталь операции", note: "Соберёт промпт 1.4 (§9.4).")
    }
    .environment(\.theme, .default)
}
