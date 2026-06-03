import SwiftUI

/// Onboarding carousel (§9.0): AI copilot · one money · many profiles · security.
struct OnboardingView: View {
    @Environment(AuthCoordinator.self) private var coordinator
    @Environment(\.theme) private var theme
    @State private var page = 0

    private struct Slide {
        let symbol: String
        let title: String
        let subtitle: String
        let cold: Bool // use the cold crypto/AI gradient
    }

    private let slides: [Slide] = [
        Slide(symbol: "sparkles", title: "ИИ-второй-пилот",
              subtitle: "Claude помогает с финансами: поддержка, коуч и действия — всегда с подтверждением.", cold: true),
        Slide(symbol: "rublesign.circle.fill", title: "Одни деньги",
              subtitle: "Рубли, цифровой рубль и крипта — в одном кошельке с мгновенной конвертацией.", cold: true),
        Slide(symbol: "person.2.fill", title: "Много профилей",
              subtitle: "Личный, бизнес, семейный и детский — под одним паспортом, переключение в один тап.", cold: false),
        Slide(symbol: "lock.shield.fill", title: "Безопасность 2035",
              subtitle: "Face ID, passkeys и подтверждение операций. Пароль — только резерв.", cold: false),
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { index in
                    slideView(slides[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Создать аккаунт", icon: "arrow.right") { coordinator.push(.register) }
                Button("Уже есть аккаунт? Войти") { coordinator.push(.login) }
                    .font(BrandFont.callout.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(slide.cold ? AnyShapeStyle(theme.cryptoGradient)
                                     : AnyShapeStyle(theme.accent.opacity(0.18)))
                    .frame(width: 140, height: 140)
                Image(systemName: slide.symbol)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(slide.cold ? .white : theme.accent)
            }
            VStack(spacing: Spacing.sm) {
                Text(slide.title)
                    .font(BrandFont.displayL)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(slide.subtitle)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var dots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? theme.accent : theme.border)
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(Motion.snappy, value: page)
            }
        }
    }
}
