import SwiftUI

/// Чаты → «Уведомления» (§9.5): a demo feed with read/unread state. Tapping a row marks it read (the
/// unread dot clears and the hub badge drops); «Прочитать все» clears the lot. Source —
/// ``NotificationsStore`` (session, demo).
struct NotificationsListView: View {
    @Environment(\.theme) private var theme

    @State private var store = NotificationsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if store.unreadCount > 0 {
                    HStack {
                        Text("\(store.unreadCount) непрочитанных")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Button("Прочитать все") { store.markAllRead() }
                            .font(BrandFont.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                            Button { store.markRead(item.id) } label: { row(item) }
                                .buttonStyle(.plain)
                            if index < store.items.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: item.kind.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint(item.kind))
                .frame(width: 36, height: 36)
                .background(tint(item.kind).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    Text(item.title)
                        .font(BrandFont.bodyM.weight(item.isRead ? .medium : .semibold))
                        .foregroundStyle(theme.textPrimary)
                    if !item.isRead { Circle().fill(theme.accent).frame(width: 7, height: 7) }
                    Spacer(minLength: Spacing.xs)
                    Text(relative(item.date))
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
                Text(item.body)
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .opacity(item.isRead ? 0.72 : 1)
    }

    private func tint(_ kind: AppNotification.Kind) -> Color {
        switch kind {
        case .security: return theme.danger
        case .payment:  return theme.accent
        case .product:  return theme.success
        case .system:   return theme.warning
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
