import SwiftUI
import Observation

/// Loads the lightweight data the payments hub shows up front (§9.2): the profile's accounts (for
/// the «Между счетами» rail + a balance peek) and the curated offers/templates. Network calls go
/// through ``APIClient``; payments-only fixtures come from ``PaymentsMockData``.
@MainActor
@Observable
final class PaymentsHubModel {
    var accounts: [Account] = []
    var isLoading = true

    let offers = PaymentsMockData.offers
    let templates = PaymentsMockData.templates

    /// The transfer rails surfaced on the hub, in display order (§9.2).
    let rails: [TransferKind] = [
        .betweenAccounts, .byPhone, .byCard, .byRequisites,
        .abroad, .cryptoToContact, .digitalRubleQR,
    ]

    /// The quick-tile sections (§9.2 «плитки Мои платежи / ЖКУ / Штрафы»).
    let sections: [BillerSection] = [.myPayments, .utilities, .fines]

    func load(api: any APIClient, session: AppSession) async {
        let profileId = session.activeProfile?.id ?? ""
        accounts = (try? await api.accounts(profileId: profileId)) ?? []
        isLoading = false
    }

    /// Total ₽-like balance across fiat accounts (a small "доступно к переводу" peek).
    var rubBalance: Double {
        accounts.filter(\.isRubLike).reduce(0) { $0 + $1.balance }
    }
}
