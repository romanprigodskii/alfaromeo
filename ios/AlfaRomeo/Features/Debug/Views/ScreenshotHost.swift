#if DEBUG
import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

/// TEMPORARY verification harness (NOT shipped — `#if DEBUG`, launch-arg only). Drives the **real**
/// ``HistoryStore`` mutations (add expense / re-categorize / custom category / dispute) and the real
/// document generators, then renders the resulting screen so the work can be screenshotted without
/// idb/UI-automation. Selected via `-ARShot <name>` (see AlfaRomeoApp). Reverted after capture.
struct ScreenshotHost: View {
    let name: String

    @State private var ready = false
    @State private var receiptURL: URL?
    @State private var reportURL: URL?

    /// Module shots added for the design passes; their screens load their own stores.
    private static let selfLoadingShots: Set<String> = [
        "cardsHub", "cardDetail", "mobileHub", "mobileTariffs", "savingsHub", "openDeposit",
        "onboarding", "login", "splash", "copilotChat", "subscription", "transferFlow", "paymentsTemplates",
    ]

    var body: some View {
        Group {
            if ready { content } else { ProgressView().controlSize(.large) }
        }
        .environment(AppSession.mockAuthenticated())
        .environment(ShellState())
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
        .environment(\.theme, .default)
        .task { await seed() }
    }

    @ViewBuilder private var content: some View {
        switch name {
        case "historyFeed":
            NavigationStack { HistoryView().navigationTitle("История").navigationBarTitleDisplayMode(.inline) }
        case "analytics":
            NavigationStack { BudgetAnalyticsView() }
        case "categories":
            NavigationStack { CategoriesView() }
        case "opDetailDisputed":
            NavigationStack { OperationDetailView(txId: "t7") }       // disputed → ticket card
        case "opDetailCategorized":
            NavigationStack { OperationDetailView(txId: "t1") }       // re-categorized Пятёрочка → Кафе
        case "picker":
            CategoryPickerSheet(selection: .constant(CategoryRef(.dining))).padding(Spacing.lg)

        // ── Счёт (детейл) · Главный (§9.1) — personal profile; seed() loads HistoryStore so the
        //    per-account feed (resolvedAccountId heuristic) has data ──
        case "accountDetailCurrent":
            NavigationStack { AccountDetailScreen(accountId: "acc_cur") }   // богатая ₽-лента
        case "accountDetailEmpty":
            NavigationStack { AccountDetailScreen(accountId: "acc_sav") }   // нет операций → пустое состояние
        case "accountDetailCrypto":
            NavigationStack { AccountDetailScreen(accountId: "acc_cr") }    // USDT + ₽-эквивалент

        // ── Выгода / Benefits (§9.3) — tier-gated via ForceTier on the personal profile ──
        case "benefitsHub":
            NavigationStack { BenefitsView().navigationTitle("Выгода") }
        case "benefitsCategories":              // Pro default → 1 из 3 slots
            NavigationStack { CategorySelectionView() }
        case "benefitsCategoriesBase":          // Base → 1 slot + soft upsell, premium row locked
            NavigationStack { ForceTier(.base) { CategorySelectionView() } }
        case "benefitsCategoriesInfinite":      // Infinite → без лимита, premium row unlocked
            NavigationStack { ForceTier(.infinite) { CategorySelectionView() } }
        case "benefitsSuper":                   // Pro → active super-cashback card + picker
            NavigationStack { SuperCashbackView() }
        case "benefitsSuperBase":               // Base → locked, full UpsellCard (no picker)
            NavigationStack { ForceTier(.base) { SuperCashbackView() } }
        case "benefitsOffers":                  // Pro → partner catalog + Infinite teaser
            NavigationStack { PartnerOffersView() }
        case "benefitsOffersInfinite":          // Infinite → exclusive premium-partner section
            NavigationStack { ForceTier(.infinite) { PartnerOffersView() } }

        case "receiptPDF":
            pdf(receiptURL)
        case "reportPDF":
            pdf(reportURL)

        // ── Кредиты (§10.5) — self-contained CreditStore, no seeding needed ──
        case "creditHub":
            NavigationStack { CreditView() }
        case "creditPrequal":
            NavigationStack { PrequalView() }
        case "creditPrequalSim":
            NavigationStack { CreditSimShot() }   // two levers applied → recomputed limit + «учтено»
        case "creditApplyParams":
            NavigationStack { CreditApplyView(productId: "cr_cash") }
        case "creditApplySchedule":
            NavigationStack { CreditApplyView(productId: "cr_cash", startAt: .schedule) }
        case "creditApplyConsents":
            NavigationStack { CreditApplyView(productId: "cr_cash", startAt: .consents) }
        case "creditApplyConfirm":
            NavigationStack { CreditApplyView(productId: "cr_cash", startAt: .confirm) }
        case "creditStatusSuccess":
            CreditStatusView(outcome: .success, productKind: .cash, amount: 840_000,
                             caption: "Платёж 25 100 ₽/мес · 5 лет", onDone: {}, onRetry: {})
        case "creditStatusDeclined":
            CreditStatusView(outcome: .declined(.overDebtLoad), productKind: .cash, amount: 0,
                             caption: "", onDone: {}, onRetry: {})

        // ── Бизнес · Дашборд / Счета (§8.2, §9.9) — graphite theme, business profile active ──
        case "bizDashboard":
            BizShot { NavigationStack { BusinessDashboardView() } }
        case "bizDashboardDark":
            BizShot(scheme: .dark) { NavigationStack { BusinessDashboardView() } }
        case "bizAccounts":
            BizShot { NavigationStack { BusinessAccountsView() } }
        case "bizStatements":
            BizShot { NavigationStack { BusinessStatementsView() } }
        case "bizAccountDetail":
            BizShot { NavigationStack { AccountDetailView(accountId: "bacc_trez") } }

        // ── Профиль / Настройки (§9.8) ──
        case "profile":
            NavigationStack { ProfileView() }
        case "settings":
            NavigationStack { SettingsView() }
        case "security":
            NavigationStack { SecuritySettingsView() }
        case "notifications":
            NavigationStack { NotificationsSettingsView() }
        case "themeSettings":
            NavigationStack { ThemeSettingsView() }
        // Theme really switches the whole app: same screen rendered via the real ThemeProvider, light vs dark.
        case "homeLight":
            Themed(.light) { NavigationStack { HomeView().navigationTitle("Главная").navigationBarTitleDisplayMode(.inline) } }
        case "homeDark":
            Themed(.dark) { NavigationStack { HomeView().navigationTitle("Главная").navigationBarTitleDisplayMode(.inline) } }
        case "settingsDark":
            Themed(.dark) { NavigationStack { SettingsView() } }

        // ── Оплата (§10.3) — Payments hub; the screen funnels into the real TransferFlowView ──
        case "payHub":
            NavigationStack {
                PayHubView().navigationTitle("Оплата").navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: PaymentsRoute.self) { $0.destination }
            }

        // ── Платежи (§9.2) — hub root; the «Оплата» (QR) entry now lives here (moved off the dashboard) ──
        case "paymentsHub":
            NavigationStack { PaymentsView().navigationTitle("Платежи").navigationBarTitleDisplayMode(.inline) }
        // ── Профиль-переключатель (§5.2) — only Личный + Бизнес; the child profile is gone ──
        case "profileSwitcher":
            ProfileSwitcherSheet()

        // ── Чаты (§9.5) — Обращения reuse the shared DisputeTicket; seed() disputes t7 so there's one ──
        case "chatsHub":
            NavigationStack { ChatsHubView().navigationTitle("Чаты").navigationBarTitleDisplayMode(.inline) }
        case "chatsDisputes":
            NavigationStack { DisputesListView() }
        case "chatsDisputeDetail":
            // Content is built only after seed() runs → the disputed-t7 ticket exists by now.
            NavigationStack { DisputeDetailView(ticketId: HistoryStore.shared.tickets.first?.id ?? "") }
        case "chatsNotifications":
            NavigationStack { NotificationsListView() }
        case "copilotSearch":
            // The AI-insight bar now opens this with the .search context (instead of a stub screen).
            NavigationStack { CopilotChatView(launch: .search, embedded: true) }

        // ── Биржа / Crypto hub (§9.6) — light like the rest of the app; ₽/$ toggle + a pushed Обмен flow. ──
        case "marketHub":
            CryptoShot()                                   // light hub + ₽/$ toggle (needs live prices)
        case "marketHubConvert":
            CryptoShot(push: .convert(asset: "BTC"))       // Обмен flow pushed on the hub
        case "marketAsset":
            CryptoShot(push: .assetDetail(symbol: "BTC"))   // asset detail: source badge + real klines
        case "marketAssetTON":
            CryptoShot(push: .assetDetail(symbol: "TON"))   // TON priced via GRAMUSDT upstream
        case "marketHubMock":
            // Same hub, rendered without the live-price gate so it shows offline too (proves it's light).
            NavigationStack { CryptoHubView() }
        case "coins":
            CoinGalleryShot()   // brand coin logos (BTC/ETH/USDT/USDC/SOL/TON) + ЦФА/ticker fallbacks

        // ── Дизайн-система (docs/DESIGN.md) + one entry per module for design passes ──
        case "gallery":
            DesignSystemGallery(profileType: .personal, scheme: .light)
        case "galleryDark":
            DesignSystemGallery(profileType: .personal, scheme: .dark)
        case "galleryBusiness":
            DesignSystemGallery(profileType: .business, scheme: .light)
        case "galleryCards":
            DesignSystemGallery(profileType: .personal, scheme: .light, scrollTo: .cards)
        case "galleryNumbers":
            DesignSystemGallery(profileType: .personal, scheme: .light, scrollTo: .numbers)
        case "galleryButtons":
            DesignSystemGallery(profileType: .personal, scheme: .light, scrollTo: .buttons)
        case "galleryType":
            DesignSystemGallery(profileType: .personal, scheme: .light, scrollTo: .type)
        case "cardsHub":
            NavigationStack { CardsView().navigationDestination(for: CardsRoute.self) { $0.destination } }
        case "cardDetail":
            NavigationStack { CardDetailView(cardId: "card_v") }
        case "mobileHub":
            NavigationStack { MobileHubView() }
        case "mobileTariffs":
            NavigationStack { TariffsView() }
        case "savingsHub":
            NavigationStack { SavingsHubView() }
        case "openDeposit":
            NavigationStack { OpenDepositView(productId: "dep_term") }
        case "onboarding":
            NavigationStack { OnboardingView() }.environment(AuthCoordinator())
        case "login":
            NavigationStack { LoginView() }.environment(AuthCoordinator())
        case "splash":
            SplashView()
        case "copilotChat":
            NavigationStack { CopilotChatView(launch: .standard, embedded: true) }
        case "subscription":
            NavigationStack { SubscriptionView() }
        case "transferFlow":
            NavigationStack { TransferFlowView(kind: .byPhone) }
        case "paymentsTemplates":
            NavigationStack {
                TemplatesView().navigationDestination(for: PaymentsRoute.self) { $0.destination }
            }

        default:
            Text("unknown shot: \(name)")
        }
    }

    @ViewBuilder private func pdf(_ url: URL?) -> some View {
        #if canImport(PDFKit)
        if let url { PDFPreview(url: url).ignoresSafeArea() } else { Text("no document") }
        #else
        Text("PDFKit unavailable")
        #endif
    }

    private func seed() async {
        // Benefits / Credit / Settings-family / Market shots need no History seeding — their stores seed
        // themselves (the Crypto hub loads live prices + portfolio in its own host, below).
        if name.hasPrefix("benefits") || name.hasPrefix("credit") || name.hasPrefix("settings")
            || name.hasPrefix("profile") || name.hasPrefix("home") || name.hasPrefix("security")
            || name.hasPrefix("notif") || name.hasPrefix("theme") || name.hasPrefix("biz")
            || name.hasPrefix("market") || name == "coins" { ready = true; return }
        // Design-pass module shots: each screen loads its own store.
        if Self.selfLoadingShots.contains(name) || name.hasPrefix("gallery") { ready = true; return }

        let pid = MockData.personalProfileId
        let store = HistoryStore.shared
        await store.load(api: MockAPIClient(), profileId: pid, force: true)

        // #5 custom category, #1 manual expense assigned to it (lands at the top of the feed),
        let pets = store.addCustomCategory(title: "Питомцы", icon: "pawprint.fill", tintHex: 0xBF5AF2)
        store.addExpense(amount: 3_490, category: CategoryRef(pets), note: "Зоомагазин «Лапка»",
                         date: store.referenceDate ?? Date(), profileId: pid)
        // #2 re-categorize an existing operation (Пятёрочка: Продукты → Кафе),
        store.setCategory(txId: "t1", ref: CategoryRef(.dining))
        // #4 dispute the declined Steam charge,
        if let t7 = store.transaction(id: "t7") { _ = store.dispute(t7, category: store.category(for: t7)) }

        // #3 / #6 real generated documents.
        if let t6 = store.transaction(id: "t6") {
            receiptURL = HistoryDocuments.receiptPDF(for: t6, categoryTitle: store.category(for: t6).title,
                                                     accountTitle: "Текущий счёт")
        }
        let rows = store.allTransactions
            .sorted { ($0.createdAt) > ($1.createdAt) }
            .map { tx in
                HistoryDocuments.StatementRow(
                    id: tx.id, date: HistoryFormatting.date(tx.createdAt),
                    counterparty: tx.counterparty ?? store.category(for: tx).title,
                    category: store.category(for: tx).title, amount: tx.amount,
                    currency: tx.currency, status: "Выполнено")
            }
        reportURL = HistoryDocuments.statementPDF(periodLabel: "Всё время", rows: rows)

        ready = true
    }
}

/// Renders the credit pre-qual with two simulator levers pre-applied, so a screenshot shows the
/// recomputed (higher) limit, the hero Δ, and «учтено» on the applied rows. Credit-shot only.
private struct CreditSimShot: View {
    @State private var store = CreditStore.shared
    var body: some View {
        PrequalView().task {
            store.load(profileId: MockData.personalProfileId)
            store.appliedLevers = ["lv_close_ob_loan", "lv_income"]
        }
    }
}

/// Wraps a screen in the **real** ``ThemeProvider`` so a screenshot shows the app under an explicit
/// scheme — used to prove the theme toggle (§9.8) re-themes the whole app (light vs dark). The inner
/// theme overrides the harness's default light environment for this subtree.
private struct Themed<Content: View>: View {
    let scheme: ColorScheme?
    @ViewBuilder var content: () -> Content
    init(_ scheme: ColorScheme?, @ViewBuilder content: @escaping () -> Content) {
        self.scheme = scheme
        self.content = content
    }
    var body: some View {
        ThemeProvider(profileType: .personal, scheme: scheme) { content() }
    }
}

/// Hosts a business-mode screen for a screenshot: its own session pre-switched to the **business**
/// profile, the **graphite** business theme (light or dark), a section `Router` + the mock client, and a
/// pre-load of the business stores (счета / команда / live prices) so any root or pushed sub-screen has
/// real data without driving the tab flow. Business-shot only (`-ARShot biz…`).
private struct BizShot<Content: View>: View {
    let scheme: ColorScheme?
    @ViewBuilder var content: () -> Content

    @State private var session: AppSession = {
        let s = AppSession.mockAuthenticated()
        if let biz = s.profiles.first(where: { $0.type == .business }) { s.switchProfile(biz) }
        return s
    }()
    @State private var ready = false

    init(scheme: ColorScheme? = .light, @ViewBuilder content: @escaping () -> Content) {
        self.scheme = scheme
        self.content = content
    }

    var body: some View {
        Group {
            if ready { content() } else { ProgressView().controlSize(.large) }
        }
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
        .themeProvider(profileType: .business, scheme: scheme)
        .task {
            await LivePriceService.shared.start()
            await BusinessAccountsStore.shared.load(api: MockAPIClient(),
                                                    profileId: MockData.businessProfileId, force: true)
            await TeamStore.shared.load(api: MockAPIClient(), profileId: MockData.businessProfileId,
                                        currentUserId: MockData.userId, force: true)
            ready = true
        }
    }
}

/// Renders the brand coin logos through the real ``AssetGlyph`` path (known coins → ``CoinLogo``), plus
/// the ЦФА `systemImage` and unknown-ticker fallbacks, at a few sizes — so a screenshot proves the
/// hand-drawn ETH/SOL/TON marks and the ₿/₮/$ glyphs look right. Coins-shot only.
private struct CoinGalleryShot: View {
    private let coins = ["BTC", "ETH", "USDT", "USDC", "SOL", "TON"]
    var body: some View {
        VStack(spacing: Spacing.xl) {
            ForEach([CGFloat(64), 44, 28], id: \.self) { sz in
                HStack(spacing: Spacing.md) {
                    ForEach(coins, id: \.self) { AssetGlyph(symbol: $0, size: sz) }
                }
            }
            Divider()
            HStack(spacing: Spacing.md) {
                AssetGlyph(symbol: "AURUM", size: 44)                                  // unknown → ticker
                AssetGlyph(symbol: "CFA", systemImage: "building.columns.fill", size: 44) // ЦФА glyph
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
    }
}

/// Hosts the Crypto hub for a screenshot: pre-loads live prices + the portfolio store so the hero and
/// positions render fully, then optionally pushes one ``CryptoRoute`` on top. The hub is light like the
/// rest of the app (no chrome). It owns the `NavigationStack`, so routes resolve exactly as in the app.
/// Reuses the harness-injected AppSession / Router / mock client / theme. Market-shot only.
private struct CryptoShot: View {
    var push: CryptoRoute? = nil

    @State private var path = NavigationPath()
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                NavigationStack(path: $path) {
                    CryptoHubView()
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .task {
            await LivePriceService.shared.start()
            await CryptoStore.shared.load(api: MockAPIClient(),
                                          profileId: MockData.personalProfileId, force: true)
            if let push {
                // Skip the unqualified-investor risk-test gate so the pushed flow's own screen renders.
                CryptoStore.shared.passRiskTest()
                path.append(push)
            }
            ready = true
        }
    }
}

/// Forces a tier override on the personal profile so a screenshot can exercise a tier-gated state
/// (Base lock / Infinite unlock) without driving the subscription flow. Benefits-shot only.
private struct ForceTier<Content: View>: View {
    let tier: Tier
    @ViewBuilder var content: () -> Content
    @Environment(AppSession.self) private var session

    init(_ tier: Tier, @ViewBuilder content: @escaping () -> Content) {
        self.tier = tier
        self.content = content
    }

    var body: some View {
        content().task { session.setTier(tier, for: MockData.personalProfileId) }
    }
}

#if canImport(PDFKit)
private struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { view.document = PDFDocument(url: url) }
}
#endif
#endif
