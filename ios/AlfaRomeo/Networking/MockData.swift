import Foundation

/// Rich demo fixtures backing ``MockAPIClient`` — one personal + one business profile, with
/// several accounts, cards, transactions, a crypto portfolio, a mobile plan, and a business set.
/// The app runs end-to-end on these without a backend.
enum MockData {
    static let userId = "u_demo"
    static let personalProfileId = "p_personal"
    static let businessProfileId = "p_business"
    static let childProfileId = "p_child"

    static let user = User(
        id: userId, phone: "+7 999 000-00-00",
        kycStatus: .verified, investorStatus: .unqualified, createdAt: "2035-01-01T00:00:00Z"
    )

    static let profiles: [Profile] = [
        Profile(id: personalProfileId, userId: userId, type: .personal,
                displayName: "Личный", theme: nil, createdAt: "2035-01-01T00:00:00Z"),
        Profile(id: businessProfileId, userId: userId, type: .business,
                displayName: "ООО Ромашка", theme: nil, createdAt: "2035-02-01T00:00:00Z"),
        Profile(id: childProfileId, userId: userId, type: .child,
                displayName: "Детский · Артём", theme: nil, createdAt: "2035-03-01T00:00:00Z"),
    ]

    static func membership(_ profileId: String) -> Membership {
        Membership(userId: userId, profileId: profileId, role: .owner, permissions: ["*"])
    }

    static func subscription(_ profileId: String) -> Subscription {
        switch profileId {
        case businessProfileId:
            return Subscription(profileId: profileId, tier: .bizPro, status: .active,
                                renewsAt: "2035-07-01T00:00:00Z", price: 2_900)
        case childProfileId:
            return Subscription(profileId: profileId, tier: .base, status: .active,
                                renewsAt: nil, price: nil)
        case personalProfileId:
            return Subscription(profileId: profileId, tier: .pro, status: .trialing,
                                renewsAt: "2035-07-01T00:00:00Z", price: 990)
        default:
            return Subscription(profileId: profileId, tier: .base, status: .active,
                                renewsAt: nil, price: nil)
        }
    }

    // MARK: Accounts

    static let personalAccounts: [Account] = [
        Account(id: "acc_cur", profileId: personalProfileId, type: .current, currency: "RUB", balance: 184_200.50),
        Account(id: "acc_sav", profileId: personalProfileId, type: .savings, currency: "RUB", balance: 920_000),
        Account(id: "acc_dr",  profileId: personalProfileId, type: .digitalRuble, currency: "RUB", balance: 15_000),
        Account(id: "acc_cr",  profileId: personalProfileId, type: .crypto, currency: "USDT", balance: 1_820.40),
    ]
    // РКО for the demo ООО (§8.2): a ₽ settlement account, a USD multicurrency account, and a crypto
    // treasury in two stablecoins (USDT + USDC) — «стейблкоины как операционная валюта». `bacc_cur`
    // stays first current·RUB and `bacc_trez` first `.crypto`, so AcquiringStore's `.first` lookups
    // (settlement + treasury) keep resolving unchanged.
    static let businessAccounts: [Account] = [
        Account(id: "bacc_cur",  profileId: businessProfileId, type: .current, currency: "RUB",  balance: 2_413_900),
        Account(id: "bacc_usd",  profileId: businessProfileId, type: .current, currency: "USD",  balance: 18_400),
        Account(id: "bacc_trez", profileId: businessProfileId, type: .crypto,  currency: "USDT", balance: 50_000),
        Account(id: "bacc_usdc", profileId: businessProfileId, type: .crypto,  currency: "USDC", balance: 12_000),
    ]
    static let childAccounts: [Account] = [
        Account(id: "cacc_cur", profileId: childProfileId, type: .current, currency: "RUB", balance: 3_250),
        Account(id: "cacc_sav", profileId: childProfileId, type: .savings, currency: "RUB", balance: 12_000),
    ]
    static func accounts(_ profileId: String) -> [Account] {
        switch profileId {
        case personalProfileId: return personalAccounts
        case businessProfileId: return businessAccounts
        case childProfileId:    return childAccounts
        default:                return []
        }
    }

    // MARK: Cards

    // Two cards (consistent with the Pro 3-card limit) so the tier gate demos cleanly:
    // on Base (limit 1) ordering another is blocked; on Pro (limit 3) it is allowed.
    static let personalCards: [Card] = [
        Card(id: "card_v", accountId: "acc_cur", profileId: personalProfileId, type: .virtual, last4: "4921", state: .active, designId: "pro", isDefault: true, assetLink: nil),
        Card(id: "card_p", accountId: "acc_cur", profileId: personalProfileId, type: .plastic, last4: "1180", state: .active, designId: "pro", isDefault: false, assetLink: nil),
    ]
    static let businessCards: [Card] = [
        Card(id: "bcard_v", accountId: "bacc_cur", profileId: businessProfileId, type: .virtual, last4: "8800", state: .active, designId: "biz", isDefault: true, assetLink: nil),
    ]
    static let childCards: [Card] = [
        Card(id: "ccard_v", accountId: "cacc_cur", profileId: childProfileId, type: .virtual, last4: "4242", state: .active, designId: "child", isDefault: true, assetLink: nil),
    ]
    static func cards(_ profileId: String) -> [Card] {
        switch profileId {
        case personalProfileId: return personalCards
        case businessProfileId: return businessCards
        case childProfileId:    return childCards
        default:                return []
        }
    }

    static func cardOrders(_ profileId: String) -> [CardOrder] {
        guard profileId == personalProfileId else { return [] }
        return [
            CardOrder(id: "co_1", profileId: personalProfileId, cardType: .plastic, designId: "pro",
                      virtualIssuedAt: "2035-03-01T10:00:00Z", physicalStatus: .shipping,
                      tracking: "RM-2035-000114", address: "Москва, Пресненская наб., 8"),
        ]
    }

    // MARK: Transactions

    static let personalTransactions: [Transaction] = [
        Transaction(id: "t8", profileId: personalProfileId, kind: .payment, status: .processing, amount: -7_800, currency: "RUB", counterparty: "Wildberries", fee: 0, fxRate: nil, createdAt: "2035-06-02T07:30:00Z"),
        Transaction(id: "t1", profileId: personalProfileId, kind: .payment, status: .completed, amount: -1_240.50, currency: "RUB", counterparty: "Пятёрочка", fee: 0, fxRate: nil, createdAt: "2035-06-01T09:14:00Z"),
        Transaction(id: "t2", profileId: personalProfileId, kind: .transfer, status: .completed, amount: -5_000, currency: "RUB", counterparty: "Иван П.", fee: 0, fxRate: nil, createdAt: "2035-06-01T12:02:00Z"),
        Transaction(id: "t3", profileId: personalProfileId, kind: .payment, status: .completed, amount: -399, currency: "RUB", counterparty: "Яндекс Плюс", fee: 0, fxRate: nil, createdAt: "2035-05-31T08:00:00Z"),
        Transaction(id: "t4", profileId: personalProfileId, kind: .convert, status: .completed, amount: 45_000, currency: "RUB", counterparty: "BTC → ₽", fee: 120, fxRate: 9_540_000, createdAt: "2035-05-30T18:40:00Z"),
        Transaction(id: "t5", profileId: personalProfileId, kind: .trade, status: .completed, amount: -32_000, currency: "RUB", counterparty: "Покупка ETH", fee: 80, fxRate: 318_000, createdAt: "2035-05-29T15:20:00Z"),
        Transaction(id: "t6", profileId: personalProfileId, kind: .payout, status: .completed, amount: 210_000, currency: "RUB", counterparty: "Зарплата", fee: 0, fxRate: nil, createdAt: "2035-05-25T10:00:00Z"),
        Transaction(id: "t7", profileId: personalProfileId, kind: .payment, status: .declined, amount: -2_599, currency: "RUB", counterparty: "Steam", fee: 0, fxRate: nil, createdAt: "2035-05-24T21:10:00Z"),
    ]
    static let businessTransactions: [Transaction] = [
        Transaction(id: "bt1", profileId: businessProfileId, kind: .acquire, status: .completed, amount: 128_000, currency: "RUB", counterparty: "Эквайринг QR", fee: 1_280, fxRate: nil, createdAt: "2035-06-01T11:00:00Z"),
        Transaction(id: "bt2", profileId: businessProfileId, kind: .payout, status: .processing, amount: -1_680_000, currency: "RUB", counterparty: "Зарплатный реестр", fee: 0, fxRate: nil, createdAt: "2035-06-02T06:00:00Z"),
        Transaction(id: "bt3", profileId: businessProfileId, kind: .convert, status: .completed, amount: 460_000, currency: "RUB", counterparty: "USDT → ₽ (трежери)", fee: 900, fxRate: 92, createdAt: "2035-05-28T13:00:00Z"),
    ]
    static let childTransactions: [Transaction] = [
        Transaction(id: "ct1", profileId: childProfileId, kind: .transfer, status: .completed, amount: 1_000, currency: "RUB", counterparty: "Перевод от мамы", fee: 0, fxRate: nil, createdAt: "2035-06-01T10:00:00Z"),
        Transaction(id: "ct2", profileId: childProfileId, kind: .payment, status: .completed, amount: -150, currency: "RUB", counterparty: "Самокат", fee: 0, fxRate: nil, createdAt: "2035-06-01T14:20:00Z"),
        Transaction(id: "ct3", profileId: childProfileId, kind: .payment, status: .completed, amount: -320, currency: "RUB", counterparty: "Кафе", fee: 0, fxRate: nil, createdAt: "2035-05-31T13:05:00Z"),
    ]
    static func transactions(_ profileId: String) -> [Transaction] {
        switch profileId {
        case personalProfileId: return personalTransactions
        case businessProfileId: return businessTransactions
        case childProfileId:    return childTransactions
        default:                return []
        }
    }

    // MARK: Crypto

    static let wallets: [CryptoWallet] = [
        CryptoWallet(id: "w_btc",  profileId: personalProfileId, asset: "BTC",  chain: "bitcoin",  address: "bc1q…h2k9", balance: 0.1423),
        CryptoWallet(id: "w_eth",  profileId: personalProfileId, asset: "ETH",  chain: "ethereum", address: "0x9f…A21c", balance: 1.82),
        CryptoWallet(id: "w_usdt", profileId: personalProfileId, asset: "USDT", chain: "tron",     address: "TQ…rXm",  balance: 1_820.40),
        CryptoWallet(id: "w_sol",  profileId: personalProfileId, asset: "SOL",  chain: "solana",   address: "5H…uR9",  balance: 12.5),
    ]
    static func cryptoWallets(_ profileId: String) -> [CryptoWallet] {
        profileId == personalProfileId ? wallets : []
    }

    static let allOrders: [Order] = [
        Order(id: "o1", profileId: personalProfileId, asset: "BTC", side: .buy,  type: .market, qty: 0.05, price: 9_500_000, status: .filled, createdAt: "2035-05-30T18:40:00Z"),
        Order(id: "o2", profileId: personalProfileId, asset: "ETH", side: .buy,  type: .limit,  qty: 1.0,  price: 300_000,   status: .open,   createdAt: "2035-06-01T10:00:00Z"),
        Order(id: "o3", profileId: personalProfileId, asset: "SOL", side: .sell, type: .market, qty: 5,    price: 14_000,    status: .filled, createdAt: "2035-05-22T09:00:00Z"),
    ]
    static func orders(_ profileId: String) -> [Order] {
        profileId == personalProfileId ? allOrders : []
    }

    static let allDeposits: [Deposit] = [
        Deposit(id: "d1", profileId: personalProfileId, kind: .ruble, asset: nil, principal: 500_000, rateApy: 16.5, term: 6, lockUntil: "2035-12-01T00:00:00Z"),
        Deposit(id: "d2", profileId: personalProfileId, kind: .stake, asset: "ETH", principal: 1.0, rateApy: 4.2, term: nil, lockUntil: "2035-09-01T00:00:00Z"),
    ]
    static func deposits(_ profileId: String) -> [Deposit] {
        profileId == personalProfileId ? allDeposits : []
    }

    // MARK: Mobile

    static func mobilePlan(_ profileId: String) -> MobilePlan? {
        guard profileId == personalProfileId else { return nil }
        return MobilePlan(profileId: personalProfileId, msisdn: "+7 999 123-45-67", esimId: "esim_001",
                          tariff: "M", dataGb: 30, minutes: 600, usedGb: 11.4, usedMin: 210, roaming: false)
    }

    // MARK: Prices (₽ snapshot)

    static func prices(_ assets: [String]) -> [PriceTick] {
        let ts = "2035-06-02T09:00:00Z"
        let table: [String: (Double, Double)] = [
            "BTC": (9_540_000, 2.4), "ETH": (318_000, -1.1), "USDT": (92, 0.0),
            "SOL": (14_200, 5.2), "TON": (610, 1.3),
        ]
        let wanted = assets.isEmpty ? Array(table.keys).sorted() : assets
        return wanted.compactMap { asset in
            guard let entry = table[asset.uppercased()] else { return nil }
            return PriceTick(asset: asset.uppercased(), price: entry.0, changePct24h: entry.1, ts: ts)
        }
    }

    /// Synthesized OHLC candles for the mock (`candles(asset:range:)`) — a deterministic seeded walk
    /// off the snapshot price, so charts render offline without the backend. The live source is the
    /// backend's `/prices/:asset/candles`.
    static func candles(_ asset: String, range: CandleRange) -> [PriceCandle] {
        let base = prices([asset]).first?.price ?? 1_000
        let count: Int
        switch range {
        case .day:     count = 24
        case .week:    count = 42
        case .month:   count = 30
        case .quarter: count = 45
        case .year:    count = 52
        }
        var seed = UInt64(asset.uppercased().unicodeScalars.reduce(0) { $0 &+ UInt32($1.value) }) &+ 1
        func next() -> Double {                       // deterministic LCG in 0..<1
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }
        let formatter = ISO8601DateFormatter()
        let now = Date(timeIntervalSince1970: 2_064_700_800)   // fixed (2035-06-02) for determinism
        let step = (range == .day) ? 3600.0 : 86_400.0
        var price = base * 0.96
        var out: [PriceCandle] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let drift = (next() - 0.48) * 0.03
            let open = price
            let close = max(0.01, open * (1 + drift))
            let high = max(open, close) * (1 + next() * 0.012)
            let low = min(open, close) * (1 - next() * 0.012)
            let t = formatter.string(from: now.addingTimeInterval(-Double(i) * step))
            out.append(PriceCandle(t: t, o: round(open), h: round(high), l: round(low), c: round(close)))
            price = close
        }
        return out
    }

    // MARK: Business

    static func business(_ profileId: String) -> Business? {
        guard profileId == businessProfileId else { return nil }
        return Business(profileId: businessProfileId, legalForm: .ooo,
                        ogrn: "1157746000000", inn: "7701234567", name: "ООО Ромашка")
    }
    static func counterparties(_ businessId: String) -> [Counterparty] {
        guard businessId == businessProfileId else { return [] }
        return [
            Counterparty(id: "cp1", businessId: businessId, inn: "7709876543", name: "ООО Поставщик", account: "40702810…001"),
            Counterparty(id: "cp2", businessId: businessId, inn: "770512345678", name: "ИП Сидоров", account: "40802810…777"),
        ]
    }
    static func invoices(_ businessId: String) -> [Invoice] {
        guard businessId == businessProfileId else { return [] }
        return [
            Invoice(id: "inv1", businessId: businessId, counterpartyId: "cp1", amount: 240_000, status: .sent, due: "2035-06-15T00:00:00Z"),
            Invoice(id: "inv2", businessId: businessId, counterpartyId: "cp2", amount: 86_500, status: .paid, due: "2035-05-20T00:00:00Z"),
        ]
    }
    static func payrollRuns(_ businessId: String) -> [PayrollRun] {
        guard businessId == businessProfileId else { return [] }
        return [PayrollRun(id: "pr1", businessId: businessId, status: .processing, itemsCount: 8, totalAmount: 1_680_000)]
    }
    static func acquiringPoints(_ businessId: String) -> [AcquiringPoint] {
        guard businessId == businessProfileId else { return [] }
        return [
            AcquiringPoint(id: "ap1", businessId: businessId, type: .qr, label: "Касса №1"),
            AcquiringPoint(id: "ap2", businessId: businessId, type: .online, label: "Платёжная ссылка"),
            AcquiringPoint(id: "ap3", businessId: businessId, type: .crypto, label: "USDT-приём"),
        ]
    }
    static func approvalRequests(_ businessId: String) -> [ApprovalRequest] {
        guard businessId == businessProfileId else { return [] }
        return [ApprovalRequest(id: "ar1", businessId: businessId, opId: "bt2", required: 2, signedBy: [userId], status: .pending)]
    }
}
