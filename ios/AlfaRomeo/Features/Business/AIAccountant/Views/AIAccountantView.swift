import SwiftUI

/// AI-бухгалтер — the business-mode AI screen (§8.2). One surface that combines:
///  • ready-made insight cards (90-day cash-flow forecast on Swift Charts, the cash-gap warning with
///    amount + date, tax optimization, expense analysis), and
///  • a live streaming chat in business context — REUSING the Phase-3 AI stack (``CopilotService`` →
///    `POST /ai/chat`, mode `"business"`) with the agentic `create_invoice` / `pay_supplier` drafts
///    confirmed through the shared biometric ``CopilotActionSheet``.
///
/// It is the `.chats` tab root in business mode (own screen, no personal floating-copilot FAB over the
/// composer). Tapping an insight card's CTA seeds a question, so the chat explains the very card above.
struct AIAccountantView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var model: AIAccountantChatModel?
    @State private var scenario = BusinessCashflowMock.scenario()
    @State private var activeDraft: AIToolDraft?

    /// Scope the chat + drafts to the active business profile (the backend grounds any business-looking
    /// id in the cashflow scenario; falls back to the canonical business demo id).
    private var profileId: String { session.activeProfile?.id ?? "profile-business-demo" }

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(theme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.background)
                }
            }
            .navigationTitle("AI-бухгалтер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AvatarButton() }
                ToolbarItem(placement: .topBarTrailing) { liveBadge }
            }
        }
        .task { await ensureModel() }
    }

    // MARK: - Model (tier → AI daily limit), mirrors CopilotChatView.ensureModel

    private func ensureModel() async {
        guard model == nil else { return }
        let fallback = (try? await api.subscription(profileId: profileId))?.tier ?? .bizStart
        let tier = session.currentTier(for: profileId, fallback: fallback)
        let limit = Entitlements.make(for: tier).aiRequestsPerDay
        let built = AIAccountantChatModel(profileId: profileId, tier: tier, aiLimit: limit)
        built.prepareOpening()
        model = built
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: AIAccountantChatModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
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
        .sheet(item: $activeDraft) { draft in
            CopilotActionSheet(draft: draft, profileId: profileId) { receipt in
                model.appendReceipt(receipt)
            }
            .themeProvider(profileType: session.activeProfile?.type)
        }
    }

    private func transcript(_ model: AIAccountantChatModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    insightDigest(model)

                    AccountantQuickPromptBar { prompt in model.quickPrompt(prompt) }
                        .padding(.horizontal, -Spacing.lg) // the bar manages its own edge padding

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                        Text("Диалог с AI-бухгалтером")
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                        Rectangle().fill(theme.border).frame(height: 1)
                    }
                    .padding(.top, Spacing.xs)

                    ForEach(model.messages) { message in
                        AccountantBubble(message: message) { draft in
                            activeDraft = draft
                        }
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.last?.text) { _, _ in
                if model.hasConversation { scrollToBottom(proxy, animated: false) }
            }
            .onChange(of: model.messages.count) { _, _ in
                if model.hasConversation { scrollToBottom(proxy) }
            }
        }
    }

    private func insightDigest(_ model: AIAccountantChatModel) -> some View {
        VStack(spacing: Spacing.md) {
            CashflowForecastCard(scenario: scenario)

            if let gap = scenario.gap {
                CashGapAlertCard(gap: gap) {
                    model.quickPrompt("Когда возможен кассовый разрыв и на какую сумму? Как его закрыть?")
                }
            }

            TaxOptimizationCard(tax: scenario.tax) {
                model.quickPrompt("Как снизить налоговую нагрузку сменой режима налогообложения? Посчитай эффект.")
            }

            ExpenseBreakdownCard(scenario: scenario) {
                model.quickPrompt("Разбери мои расходы по категориям и подскажи, где можно сэкономить.")
            }
        }
    }

    private var liveBadge: some View {
        let live = model?.isLive ?? false
        return HStack(spacing: Spacing.xxs) {
            Circle().fill(live ? theme.success : theme.warning).frame(width: 6, height: 6)
            Text(live ? "Claude · на связи" : "Claude")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
        }
        .accessibilityLabel(live ? "Claude на связи" : "Claude офлайн-демо")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        } else {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private static let bottomAnchor = "accountant-bottom"
}
