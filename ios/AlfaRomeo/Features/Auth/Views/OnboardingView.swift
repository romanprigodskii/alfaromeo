import SwiftUI

/// Onboarding carousel (§9.0): AI copilot, one wallet, many profiles, security.
struct OnboardingView: View {
    @Environment(AuthCoordinator.self) private var coordinator
    @Environment(\.theme) private var theme
    @State private var page = 0

    private struct Slide {
        let symbol: String
        let title: String
        let subtitle: String
    }

    private let slides: [Slide] = [
        Slide(symbol: "text.bubble", title: "ИИ-помощник",
              subtitle: "Claude отвечает на вопросы о финансах и готовит платежи. Каждое действие вы подтверждаете сами."),
        Slide(symbol: "rublesign", title: "Один кошелёк",
              subtitle: "Рубли, цифровой рубль и криптовалюта в одном месте. Конвертация мгновенная."),
        Slide(symbol: "person.2", title: "Профили",
              subtitle: "Личный, бизнес, семейный и детский по одному паспорту. Переключение в один тап."),
        Slide(symbol: "lock.shield", title: "Безопасность",
              subtitle: "Вход по Face ID и passkey, подтверждение каждой операции. Пароль остаётся резервом."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMark(subtitle: nil)
                .padding(.top, Spacing.md)

            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { index in
                    slideView(slides[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.bottom, Spacing.lg)

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Создать аккаунт") { coordinator.push(.register) }
                SecondaryButton(title: "Войти") { coordinator.push(.login) }
            }
            .padding(.bottom, Spacing.sm)
        }
        .padding(.horizontal, Spacing.screen)
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Spacer()
            GlyphCircle(systemImage: slide.symbol, size: 64)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(slide.title)
                    .font(BrandFont.title1)
                    .foregroundStyle(theme.textPrimary)
                Text(slide.subtitle)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.lg)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? theme.textPrimary : theme.textTertiary.opacity(0.5))
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .animation(Motion.snappy, value: page)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Экран \(page + 1) из \(slides.count)")
    }
}
