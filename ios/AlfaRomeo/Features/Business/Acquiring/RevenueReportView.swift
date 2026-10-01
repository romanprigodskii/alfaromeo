import SwiftUI

/// §8.2 — Отчёт по выручке: сводка + фильтры + список поступлений.
/// Pushed destination (AcquiringRoute.revenue).
struct RevenueReportView: View {
    @Environment(\.theme) private var theme
    @Environment(\.apiClient) private var api
    @Environment(AppSession.self) private var session

    @State private var store = AcquiringStore.shared
    @State private var prices = LivePriceService.shared
    @State private var filter: RevenueFilter = .all

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                RevenueSummaryHeader(summary: store.summary(), isLive: prices.isLive)

                filterChips

                let entries = store.filteredRevenue(filter)
                if entries.isEmpty {
                    Text("Нет поступлений по фильтру")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    GroupedSection {
                        ForEach(entries) { e in
                            RevenueEntryRow(entry: e)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Выручка")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await prices.start() }
        .animation(Motion.snappy, value: filter)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(RevenueFilter.allCases) { item in
                    let isSelected = item == filter
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(BrandFont.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs + 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? theme.accent : theme.elevated)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isSelected ? Color.clear : theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }
}

private struct RevenueReportView_PreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            RevenueReportView()
                .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview {
    RevenueReportView_PreviewHost()
}
