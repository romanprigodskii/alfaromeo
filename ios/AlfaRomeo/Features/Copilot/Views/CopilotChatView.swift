import SwiftUI

/// The AI copilot chat (§10.9): streaming token-by-token answers in message bubbles, a typing indicator,
/// a monochrome «AI» monogram, a mode switcher (Поддержка / Финкоуч / Агент), one-tap escalation, and the
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
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, embedded ? Spacing.sm : 0)
            .padding(.bottom, Spacing.sm)

            Hairline()

            transcript(model)

            if model.quotaReached, let limit = model.aiLimit {
                CopilotQuotaNotice(tier: model.tier, limit: limit)
                    .padding(.horizontal, Spacing.screen)
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
            GlyphCircle(text: "AI", size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text("AI-копилот").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(liveLabel).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var liveLabel: String {
        guard let model else { return "Claude" }
        return model.isLive ? "Claude, на связи" : "Claude, офлайн-демо"
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
                    if isFresh(model) { suggestions(model) }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            // Follow the stream WITHOUT animation (token-by-token), so there are no competing 0.2s
            // scroll animations stacking up into a jerky scroll; animate only when a new message arrives.
            .onChange(of: model.messages.last?.text) { _, _ in scrollToBottom(proxy, animated: false) }
            .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    // MARK: - Welcome empty state (starter prompts)

    /// Fresh conversation: only the seeded greeting, no user turn yet → show starter prompts under it.
    private func isFresh(_ model: CopilotChatModel) -> Bool {
        model.messages.count == 1 && model.messages.first?.role == .assistant && !model.isStreaming
    }

    /// Tappable example prompts that fill + send via the existing model API (no new logic). They switch
    /// with the active mode and disappear after the first turn.
    private func suggestions(_ model: CopilotChatModel) -> some View {
        GroupedSection("Примеры запросов") {
            ForEach(suggestionPrompts(for: model.mode), id: \.text) { item in
                Button {
                    model.input = item.text
                    model.send()
                } label: {
                    ListRow(icon: item.icon, title: item.text, showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
        .padding(.top, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func suggestionPrompts(for mode: CopilotMode) -> [(icon: String, text: String)] {
        switch mode {
        case .support:
            return [("magnifyingglass", "Сколько я потратил в этом месяце?"),
                    ("creditcard", "Покажи мои подписки"),
                    ("exclamationmark.bubble", "Как оспорить операцию?"),
                    ("questionmark.circle", "Какие у меня лимиты и тариф?")]
        case .coach:
            return [("chart.line.uptrend.xyaxis", "Где я могу сэкономить?"),
                    ("target", "Составь план накоплений"),
                    ("banknote", "Куда вложить свободные деньги?"),
                    ("calendar", "Разбор трат за месяц")]
        case .agent:
            return [("arrow.up.right", "Переведи 5 000 ₽ на карту маме"),
                    ("banknote", "Открой вклад на 100 000 ₽"),
                    ("snowflake", "Заморозь мою карту"),
                    ("iphone", "Оплати мобильный на 500 ₽")]
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
