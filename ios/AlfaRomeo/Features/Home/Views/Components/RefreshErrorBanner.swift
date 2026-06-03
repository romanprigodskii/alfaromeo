import SwiftUI

/// Slim banner shown over cached content when a refresh failed
/// (§10.2 «ошибка обновления (кэш + плашка)»).
struct RefreshErrorBanner: View {
    var onRetry: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(theme.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Не удалось обновить")
                    .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text("Показаны сохранённые данные")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button(action: onRetry) {
                Text("Повторить").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
        .background(theme.warning.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(theme.warning.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Не удалось обновить, показаны сохранённые данные")
    }
}

/// Full hard-failure card — first load with no cache to fall back on (§10.2).
struct HomeErrorCard: View {
    var onRetry: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(theme.textSecondary)
                Text("Не удалось загрузить дашборд")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                PrimaryButton(title: "Повторить", icon: "arrow.clockwise", action: onRetry)
            }
        }
    }
}
