import SwiftUI

/// A dashboard block frame for content that is not a grouped list (the cards shelf, the operations
/// feed): THE section header (``SectionHeader``, title2 + optional text action «Все») above free
/// content. Grouped blocks use ``GroupedSection`` directly, which draws the same header.
struct DashboardSection<Content: View>: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader(title, actionTitle: actionTitle, action: action)
            content()
        }
    }
}
