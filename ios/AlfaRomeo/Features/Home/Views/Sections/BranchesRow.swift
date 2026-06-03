import SwiftUI

/// «На карте» (§9.1): an entry card to branches / ATMs on a map. Opens the branches stub
/// (``HomeRoute.branches``).
struct BranchesRow: View {
    var onTap: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            SurfaceCard(padding: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(theme.accent.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("На карте").font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        Text("Отделения и банкоматы рядом")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("На карте: отделения и банкоматы")
    }
}
