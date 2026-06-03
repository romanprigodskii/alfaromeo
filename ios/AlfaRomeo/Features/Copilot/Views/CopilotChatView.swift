import SwiftUI

/// The AI copilot chat (§10.9): streaming token-by-token answers in message bubbles, a typing indicator,
/// the cold AI gradient, a mode switcher (Поддержка / Финкоуч / Агент), one-tap escalation, and the
/// agentic confirm flow (draft card → Face ID → status). Works both as a sheet (floating button / a
/// History operation) and pushed full-screen (the Chats support channel, `embedded`).
struct CopilotChatView: View {
    let launch: CopilotLaunch
    var embedded: Bool = false

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var model: CopilotChatModel?
    @State private var activeDraft: AIToolDraft?

    private var profileId: String { session.activeProfile?.id ?? "profile-personal-demo" }

    var body: some View {
        Group {
            if let model {
                chat(model)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            }
        }
        .task { await ensureModel() }
    }

    // MARK: - Build the model (tier → AI daily limit)

    private func ensureModel() async {
        guard model == nil else { return }
        let fallback = (try? await api.subscription(profileId: profileId))?.tier ?? .base
        let tier = session.currentTier(for: profileId, fallback: fallback)
        let limit = Entitlements.make(for: tier).aiRequestsPerDay
        let built = CopilotChatModel(profileId: profileId, tier: tier, mode: launch.mode, aiLimit: limit)
        built.prepare(launch: launch)
        model = built
    }

    // MARK: - Chat

    @ViewBuilder
    private func chat(_ model: CopilotChatModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if !embedded { sheetHeader }

            VStack(spacing: Spacing.xs) {
                CopilotModePicker(mode: $model.mode)
                Text(model.mode.hint)
                    .font(BrandFont.micro)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, embedded ? Spacing.sm : 0)
            .padding(.bottom, Spacing.sm)

            Divider().overlay(theme.border)

            transcript(model)

            if model.quotaReached, let limit = model.aiLimit {
                CopilotQuotaNotice(tier: model.tier, limit: limit)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
            }

            CopilotComposer(
                text: $model.input,
                isStreaming: model.isStreaming,
                onSend: { model.send() },
                onEscalate: { model.escalate() }
            )
        }
        .background(theme.background)
        .navigationTitle(embedded ? "AI-поддержка" : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeDraft) { draft in
            CopilotActionSheet(draft: draft, profileId: profileId) { receipt in
                model.appendReceipt(receipt)
            }
            .themeProvider(profileType: session.activeProfile?.type)
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("AI-копилот").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(liveLabel).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var liveLabel: String {
        guard let model else { return "Claude" }
        return model.isLive ? "Claude · на связи" : "Claude · офлайн-демо"
    }

    private func transcript(_ model: CopilotChatModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(model.messages) { message in
                        CopilotBubble(message: message) { draft in
                            activeDraft = draft
                        }
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            // Follow the stream WITHOUT animation (token-by-token), so there are no competing 0.2s
            // scroll animations stacking up into a jerky scroll; animate only when a new message arrives.
            .onChange(of: model.messages.last?.text) { _, _ in scrollToBottom(proxy, animated: false) }
            .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        } else {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private static let bottomAnchor = "copilot-bottom"
}
