import Foundation

/// A pushed placeholder destination. Phase-0 stand-in so each section's NavigationStack/Router is
/// exercised end-to-end before real feature screens land (§9).
struct PlaceholderRoute: Hashable {
    let title: String
    let blurb: String
}
