import Foundation

/// Feature-local demo fixtures for the parts of the hub with no backend (§14: крипто-исполнение и ЦФА
/// — симуляция). The network ``MockData`` stays untouched: this seeds the ЦФА catalog, the initial
/// watch-only external wallet, the starting holdings, and staking APYs. Live prices still come from
/// the real ``LivePriceService``.
enum MockCryptoData {

    // MARK: - ЦФА catalog (§9.6 🆕)

    static let cdfas: [CDFA] = [
        CDFA(id: "cfa_aurum", ticker: "AURUM", name: "Цифровое золото",
             issuer: "АО «ГОХРАН-Токен»", operatorName: "Атомайз", category: .metal,
             priceRub: 7_450, yieldPct: 0, dayChangePct: 0.4,
             about: "Токен, обеспеченный физическим золотом в хранилище (1 токен = 1 грамм). Цена следует за рынком драгметаллов.",
             minUnits: 1),
        CDFA(id: "cfa_bond26", ticker: "ALFA-26", name: "Облигация Альфа-Ромео 2026",
             issuer: "АО «Альфа-Ромео»", operatorName: "Сбер ЦФА", category: .bond,
             priceRub: 1_012, yieldPct: 18.5, dayChangePct: 0.1,
             about: "Цифровая облигация банка с фиксированным купоном. Погашение в 2026 году, выплаты ежеквартально.",
             minUnits: 1),
        CDFA(id: "cfa_metr", ticker: "METR", name: "Метры в Москве",
             issuer: "ООО «ПИК-Токен»", operatorName: "Мастерчейн", category: .realEstate,
             priceRub: 5_300, yieldPct: 9.2, dayChangePct: 0.6,
             about: "Токенизированная доля в арендной недвижимости. Доход от арендных платежей, распределяется держателям.",
             minUnits: 1),
        CDFA(id: "cfa_romeo_eq", ticker: "ROMEO", name: "Доля в Ромео Капитал",
             issuer: "ООО «Ромео Капитал»", operatorName: "Лайтхаус", category: .equity,
             priceRub: 980, yieldPct: 0, dayChangePct: 1.8,
             about: "Цифровое право на долю в портфеле венчурных проектов банка. Цена отражает оценку фонда.",
             minUnits: 1),
        CDFA(id: "cfa_techfund", ticker: "TECH", name: "Технологический фонд",
             issuer: "АО «Тинькофф Капитал»", operatorName: "Т-ЦФА", category: .fund,
             priceRub: 1_240, yieldPct: 12.0, dayChangePct: -0.7,
             about: "Диверсифицированный фонд из ЦФА технологических компаний. Доходность историческая, не гарантирована.",
             minUnits: 1),
    ]

    static func cdfa(_ id: String) -> CDFA? { cdfas.first { $0.id == id } }

    /// Starting ЦФА holdings so the unified portfolio shows the legal path from the first open (§9.6).
    static let seededCDFAHoldings: [CDFAHolding] = [
        CDFAHolding(id: "h_aurum", cdfaId: "cfa_aurum", units: 8),
        CDFAHolding(id: "h_bond26", cdfaId: "cfa_bond26", units: 40),
    ]

    // MARK: - External wallets (§9.6 🆕, watch-only)

    /// One pre-linked watch-only wallet so the portfolio demonstrates external holdings immediately;
    /// linking more (``ExternalWalletLinkView``) appends to this.
    static let seededExternalWallets: [ExternalWallet] = [
        ExternalWallet(
            id: "ext_ledger",
            provider: .ledger,
            address: "0x7a3FbC9e21D4488f0aB2C5d6E7F8901234aBcDeF",
            label: "Ledger Nano",
            holdings: [
                ExternalHolding(asset: "BTC", balance: 0.052),
                ExternalHolding(asset: "ETH", balance: 0.41),
                ExternalHolding(asset: "USDT", balance: 500),
            ]
        )
    ]

    /// Deterministic mock balances for a newly linked wallet, derived from the address so the same
    /// address always yields the same holdings (we never touch a real chain, §14).
    static func mockHoldings(provider: ExternalWalletProvider, address: String) -> [ExternalHolding] {
        var seed = UInt64(abs(address.hashValue) % 1_000_000) &+ 7
        func next(_ range: ClosedRange<Double>) -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(seed >> 33) / Double(UInt64(1) << 31)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }
        return provider.mockAssets.map { asset in
            let balance: Double
            switch asset {
            case "BTC":  balance = next(0.005...0.25)
            case "ETH":  balance = next(0.1...3.0)
            case "USDT", "USDC": balance = next(50...3_000)
            case "SOL":  balance = next(1...40)
            case "TON":  balance = next(10...500)
            default:     balance = next(1...100)
            }
            return ExternalHolding(asset: asset, balance: (balance * 1_000).rounded() / 1_000)
        }
    }

    // MARK: - Staking (teaser; full module = 2.2)

    /// Indicative staking APY per asset (§10.6 «вклад нового поколения»). Entry only from the asset
    /// detail; the full staking flow ships in 2.2.
    static func stakingApy(for symbol: String) -> Double? {
        switch symbol.uppercased() {
        case "ETH":  return 4.2
        case "SOL":  return 6.5
        case "TON":  return 3.8
        case "USDT", "USDC": return 8.0
        default:     return nil
        }
    }
}
