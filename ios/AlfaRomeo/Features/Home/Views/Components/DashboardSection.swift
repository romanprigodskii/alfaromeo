import SwiftUI

/// A dashboard block frame: a section header (title + optional subtitle + optional trailing action)
/// above its content. The shared wrapper for every Главный block (§9.1) so spacing and typography
/// stay uniform across the dashboard.
struct DashboardSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(actionTitle).font(BrandFont.callout.weight(.medium))
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            content()
        }
    }
}
