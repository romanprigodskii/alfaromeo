import SwiftUI

struct PaymentLinkResultView: View {
    let link: PaymentLink

    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                visual
                urlCard
                actions
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(link.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            StatusPill(status: .success, text: "Готово к оплате")
            Text(link.purpose)
                .font(BrandFont.headline)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            AmountText(amount: link.amount, size: 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Visual (QR or link glyph)

    @ViewBuilder
    private var visual: some View {
        if link.kind == .qr {
            QRCodeView(string: link.url)
                .frame(maxWidth: .infinity)
        } else {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 132, height: 132)
                .background(
                    theme.accent.opacity(0.14),
                    in: Circle()
                )
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - URL card with copy

    private var urlCard: some View {
        SurfaceCard(padding: Spacing.md) {
            VStack(spacing: Spacing.sm) {
                Text(link.url)
                    .font(BrandFont.mono(13))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: copyURL) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                        Text(copied ? "Скопировано" : "Скопировать")
                            .font(BrandFont.callout.weight(.medium))
                    }
                    .foregroundStyle(copied ? theme.success : theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        (copied ? theme.success : theme.accent).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .animation(Motion.snappy, value: copied)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            if let url = URL(string: link.url) {
                ShareLink(item: url) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Поделиться")
                            .font(BrandFont.callout.weight(.semibold))
                    }
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }

            SecondaryButton(title: "Готово") {
                router.popToRoot()
            }
        }
    }

    // MARK: - Copy

    private func copyURL() {
        #if canImport(UIKit)
        UIPasteboard.general.string = link.url
        #endif
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copied = false
        }
    }
}

// MARK: - Preview

private struct PaymentLinkResultView_PreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            PaymentLinkResultView(
                link: PaymentLink(
                    id: "lnk_demo",
                    kind: .qr,
                    amount: 2490,
                    purpose: "Кофе с собой",
                    url: "https://pay.alfa-romeo.uk/i/abc123",
                    createdAt: Date()
                )
            )
            .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview {
    PaymentLinkResultView_PreviewHost()
}
