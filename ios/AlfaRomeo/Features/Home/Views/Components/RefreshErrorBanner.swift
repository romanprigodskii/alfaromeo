import SwiftUI

/// Slim banner shown over cached content when a refresh failed
/// (§10.2 «ошибка обновления (кэш + плашка)»).
struct RefreshErrorBanner: View {
    var onRetry: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .regular)).foregroundStyle(theme.statusInk(.warning))
            VStack(alignment: .leading, spacing: 1) {
                Text("Не удалось обновить")
                    .font(BrandFont.body(15, weight: .semibold)).foregroundStyle(theme.textPrimary)
                Text("Показаны сохранённые данные")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button(action: onRetry) {
                Text("Повторить").font(BrandFont.body(15, weight: .medium)).foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm + 2)
        .background(theme.warning.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Не удалось обновить, показаны сохранённые данные")
    }
}

/// Full hard-failure card: first load with no cache to fall back on (§10.2).
struct HomeErrorCard: View {
    var onRetry: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                GlyphCircle(systemImage: "wifi.exclamationmark", size: 44)
                Text("Не удалось загрузить главную")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                PrimaryButton(title: "Повторить", action: onRetry)
            }
        }
    }
}
