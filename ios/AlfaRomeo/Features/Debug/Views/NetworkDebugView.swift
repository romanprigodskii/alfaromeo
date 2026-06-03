import SwiftUI

/// Developer harness for the mock networking layer (no backend): calls every ``APIClient`` method
/// and prints a one-line result, streams live ``PriceSocket`` ticks, and streams AI tokens.
struct NetworkDebugView: View {
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var lines: [DebugLine] = []
    @State private var ticks: [PriceTick] = []
    @State private var aiText: String = ""
    @State private var running = false
    @State private var runToken = 0

    // Live prices (§11.4): off by default so the demo runs on mocks without a backend; on → real
    // data from OUR backend (REST snapshot + candles + /ws/prices stream).
    @State private var liveMode = false
    @State private var liveSnapshot: [PriceTick] = []
    @State private var liveCandleCount: Int?
    @State private var liveStatus: String = ""
    @State private var liveOK = false

    private let pid = MockData.personalProfileId
    private let bid = MockData.businessProfileId
    private let trackedAssets = ["BTC", "ETH", "USDT", "SOL", "TON"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                section("Методы APIClient (\(lines.count))") {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.label).font(BrandFont.mono(12, weight: .semibold)).foregroundStyle(theme.accent)
                            Text(line.value).font(BrandFont.mono(11)).foregroundStyle(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                livePricesControl

                if liveMode {
                    section("Live REST · GET /prices (\(liveSnapshot.count))") {
                        Text(liveStatus)
                            .font(BrandFont.mono(11))
                            .foregroundStyle(liveOK ? theme.success : theme.danger)
                        ForEach(liveSnapshot) { tick in
                            Text("\(tick.asset)  \(Int(tick.price)) ₽  " +
                                 (tick.changePct24h.map { String(format: "%+.2f%%", $0) } ?? ""))
                                .font(BrandFont.mono(12)).foregroundStyle(theme.textPrimary)
                        }
                        if let liveCandleCount {
                            Text("GET /prices/BTC/candles?range=7d → \(liveCandleCount) свечей")
                                .font(BrandFont.mono(11)).foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                section("PriceSocket · \(liveMode ? "LIVE /ws/prices" : "mock") (\(ticks.count) тиков)") {
                    let recent = Array(Array(ticks.suffix(12)).reversed().enumerated())
                    ForEach(recent, id: \.offset) { _, tick in
                        Text("\(tick.asset)  \(Int(tick.price)) ₽  " +
                             (tick.changePct24h.map { String(format: "%+.2f%%", $0) } ?? ""))
                            .font(BrandFont.mono(12)).foregroundStyle(theme.textPrimary)
                    }
                    if ticks.isEmpty {
                        Text(liveMode ? "подключение к /ws/prices…" : "ожидание тиков…")
                            .font(BrandFont.mono(11)).foregroundStyle(theme.textSecondary)
                    }
                }

                section("AI-стрим · SSE") {
                    Text(aiText.isEmpty ? "ожидание токенов…" : aiText)
                        .font(BrandFont.mono(13)).foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Сетевой слой · debug")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runToken) { await runMethodsAndAI() }
        // Re-run when the source toggles: mock ↔ our backend /ws/prices.
        .task(id: liveMode) { await runPriceTicks() }
        .task(id: liveMode) { await fetchLiveSnapshot() }
    }

    /// «Live prices» toggle (§11.4). Off → mock everywhere (works without a backend). On → real data
    /// from our backend: REST snapshot + candles + the /ws/prices stream.
    private var livePricesControl: some View {
        SurfaceCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: $liveMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live prices").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("реальные цены с нашего бэкенда (REST + WS)")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                Text(liveMode ? "источник: \(APIEnvironment.current.baseURL.absoluteString)"
                              : "источник: Mock (бэкенд не требуется)")
                    .font(BrandFont.mono(10)).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var header: some View {
        HStack {
            StatusPill(status: running ? .processing : .success, text: running ? "выполняется" : "Mock готов")
            Spacer()
            SecondaryButton(title: "Перезапустить", icon: "arrow.clockwise") { runToken += 1 }
                .frame(width: 190)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased()).font(BrandFont.micro).tracking(2).foregroundStyle(theme.textSecondary)
            SurfaceCard(padding: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) { content() }
            }
        }
    }

    // MARK: Runs

    @MainActor
    private func runMethodsAndAI() async {
        running = true
        lines = []
        aiText = ""
        await callMethods()
        await streamAI()
        running = false
    }

    @MainActor
    private func runPriceTicks() async {
        ticks = []
        let socket = PriceSocket(source: liveMode ? .live : .mock, assets: trackedAssets)
        // Live: stream until the view/section is torn down (task cancelled on toggle/disappear).
        // Mock: cap at 24 ticks like before so the offline harness settles.
        var count = 0
        for await tick in socket.ticks() {
            if Task.isCancelled { break }
            ticks.append(tick)
            count += 1
            if !liveMode && count >= 24 { socket.stop(); break }
        }
        socket.stop()
    }

    /// Live REST proof: GET /prices + a candles call against OUR backend (§11.4). Surfaces a clear
    /// error if the backend isn't running — the rest of the app still works on mocks.
    @MainActor
    private func fetchLiveSnapshot() async {
        guard liveMode else {
            liveSnapshot = []; liveCandleCount = nil; liveStatus = ""; liveOK = false
            return
        }
        let client = LiveAPIClient()
        do {
            let snap = try await client.prices(assets: trackedAssets)
            liveSnapshot = snap
            liveOK = true
            liveStatus = "OK · \(snap.count) активов · ₽-эквивалент с сервера"
            liveCandleCount = (try? await client.candles(asset: "BTC", range: .week))?.count
        } catch {
            liveSnapshot = []
            liveCandleCount = nil
            liveOK = false
            liveStatus = "Бэкенд недоступен (\(error)). Приложение работает на моках."
        }
    }

    private func add(_ label: String, _ value: String) { lines.append(DebugLine(label: label, value: value)) }

    @MainActor
    private func callMethods() async {
        do { let r = try await api.signIn(phone: "+7 999 000-00-00", code: "0000"); add("signIn", "user=\(r.user.id) token=\(r.accessToken)") } catch { add("signIn", "error: \(error)") }
        do { let u = try await api.currentUser(); add("currentUser", "\(u.id) · \(u.phone) · kyc=\(u.kycStatus.rawValue)") } catch { add("currentUser", "error: \(error)") }
        do { let p = try await api.profiles(); add("profiles", p.map { "\($0.displayName ?? $0.id)[\($0.type.rawValue)]" }.joined(separator: ", ")) } catch { add("profiles", "error: \(error)") }
        do { let m = try await api.membership(profileId: pid); add("membership", "\(m.role.rawValue) perms=\(m.permissions.joined(separator: "/"))") } catch { add("membership", "error: \(error)") }
        do { let s = try await api.subscription(profileId: pid); add("subscription", "\(s.tier.rawValue) · \(s.status.rawValue)") } catch { add("subscription", "error: \(error)") }
        do { let a = try await api.accounts(profileId: pid); add("accounts·personal", "\(a.count): " + a.map { "\($0.type.rawValue) \(Int($0.balance))\($0.currency)" }.joined(separator: ", ")) } catch { add("accounts", "error: \(error)") }
        do { let c = try await api.cards(profileId: pid); add("cards·personal", "\(c.count): " + c.map { "\($0.type.rawValue)··\($0.last4)" }.joined(separator: ", ")) } catch { add("cards", "error: \(error)") }
        do { let co = try await api.cardOrders(profileId: pid); add("cardOrders", co.map { "\($0.cardType.rawValue):\($0.physicalStatus.rawValue) \($0.tracking ?? "")" }.joined(separator: ", ")) } catch { add("cardOrders", "error: \(error)") }
        do { let t = try await api.transactions(profileId: pid); add("transactions·personal", "\(t.count) операций; первая: \(t.first?.counterparty ?? "—") \(Int(t.first?.amount ?? 0))") } catch { add("transactions", "error: \(error)") }
        do { let mp = try await api.mobilePlan(profileId: pid); add("mobilePlan", mp.map { "\($0.tariff) · \($0.usedGb)/\($0.dataGb) ГБ · роуминг=\($0.roaming)" } ?? "nil") } catch { add("mobilePlan", "error: \(error)") }
        do { let pr = try await api.prices(assets: ["BTC", "ETH", "USDT", "SOL", "TON"]); add("prices", pr.map { "\($0.asset) \(Int($0.price))" }.joined(separator: ", ")) } catch { add("prices", "error: \(error)") }
        do { let w = try await api.cryptoWallets(profileId: pid); add("cryptoWallets", w.map { "\($0.asset) \($0.balance)" }.joined(separator: ", ")) } catch { add("cryptoWallets", "error: \(error)") }
        do { let o = try await api.orders(profileId: pid); add("orders", o.map { "\($0.side.rawValue) \($0.asset) \($0.type.rawValue)·\($0.status.rawValue)" }.joined(separator: ", ")) } catch { add("orders", "error: \(error)") }
        do { let d = try await api.deposits(profileId: pid); add("deposits", d.map { "\($0.kind.rawValue) \(Int($0.principal)) @\($0.rateApy)%" }.joined(separator: ", ")) } catch { add("deposits", "error: \(error)") }
        do { let b = try await api.business(profileId: bid); add("business", b.map { "\($0.name) (\($0.legalForm.rawValue)) ИНН \($0.inn)" } ?? "nil") } catch { add("business", "error: \(error)") }
        do { let cp = try await api.counterparties(businessProfileId: bid); add("counterparties", cp.map { $0.name }.joined(separator: ", ")) } catch { add("counterparties", "error: \(error)") }
        do { let inv = try await api.invoices(businessProfileId: bid); add("invoices", inv.map { "\(Int($0.amount))₽:\($0.status.rawValue)" }.joined(separator: ", ")) } catch { add("invoices", "error: \(error)") }
    }

    @MainActor
    private func streamAI() async {
        do {
            for try await event in api.aiStream(prompt: "Как мои финансы?", profileId: pid) {
                switch event {
                case .token(let token):     aiText += token
                case .toolDraft(let draft): aiText += "\n[действие: \(draft.tool) — \(draft.summary)]\n"
                case .done:                 break
                }
            }
        } catch {
            aiText += "\n[error: \(error)]"
        }
    }
}

/// A single printed line in the debug harness.
struct DebugLine: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: String
}

#Preview {
    NavigationStack { NetworkDebugView() }
        .environment(\.theme, .default)
}
