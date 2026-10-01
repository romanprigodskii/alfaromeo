import SwiftUI

/// Чаты → «Уведомления» (§9.5): a demo feed with read/unread state. Tapping a row marks it read (the
/// unread dot clears and the hub badge drops); «Прочитать все» clears the lot. Source:
/// ``NotificationsStore`` (session, demo).
struct NotificationsListView: View {
    @Environment(\.theme) private var theme

    @State private var store = NotificationsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if store.unreadCount > 0 {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.unreadCount) непрочитанных")
                            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                        Spacer()
                        Button("Прочитать все") { store.markAllRead() }
                            .font(BrandFont.subheadline.weight(.medium))
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, Spacing.xs)
                }
                GroupedSection {
                    ForEach(store.items) { item in
                        Button { store.markRead(item.id) } label: { row(item) }
                            .buttonStyle(.row)
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    /// Monochrome glyph, title (semibold + accent dot while unread), the message body, then the time.
    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: item.kind.icon)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs + 2) {
                    Text(item.title)
                        .font(item.isRead ? BrandFont.bodyM : BrandFont.headline)
                        .foregroundStyle(theme.textPrimary)
                        .layoutPriority(1)
                    if !item.isRead {
                        Circle().fill(theme.accent).frame(width: 7, height: 7)
                            .accessibilityLabel("Не прочитано")
                    }
                    Spacer(minLength: 0)
                }
                Text(item.body)
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(relative(item.date))
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
