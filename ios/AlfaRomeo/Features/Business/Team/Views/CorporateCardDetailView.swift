import SwiftUI

/// Corp-card detail (§8.2 «управление расходами»): a graphite card face, the monthly-limit gauge,
/// freeze/unfreeze, and a limit editor. Lightweight — the full issuance pipeline lives in the Cards
/// module; here we manage the employee spend controls.
struct CorporateCardDetailView: View {
    let cardId: String

    @Environment(\.theme) private var theme
    @State private var store = TeamStore.shared
    @State private var showLimitSheet = false
    @State private var limitText = ""

    private var card: CorporateCard? { store.corpCard(id: cardId) }

    var body: some View {
        ScrollView {
            if let card {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    cardFace(card)
                    limitCard(card)
                    controls(card)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Карта не найдена").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.screen)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Корп-карта")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Месячный лимит", isPresented: $showLimitSheet) {
            TextField("Лимит, ₽", text: $limitText).keyboardType(.numberPad)
            Button("Сохранить") {
                store.setCardLimit(SupplierPaymentModel.parse(limitText), cardId: cardId)
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func cardFace(_ card: CorporateCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CardArt(last4: card.last4, label: card.holderName, style: .graphite, isFrozen: card.isFrozen)
            Text([card.kind.label,
                  store.member(id: card.holderUserId).map { RoleCatalog.label($0.role) } ?? "Сотрудник",
                  card.isFrozen ? "заморожена" : nil].compactMap { $0 }.prefix(2).joined(separator: " · "))
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
    }

    private func limitCard(_ card: CorporateCard) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Месячный лимит").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button { limitText = String(Int(card.monthlyLimit)); showLimitSheet = true } label: {
                        Text("Изменить").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                ProgressBar(value: card.spentProgress, height: 8)
                HStack {
                    Text("Потрачено \(SupplierPaymentModel.rub(card.monthlySpent))")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary).monospacedDigit()
                    Spacer()
                    Text("Осталось \(SupplierPaymentModel.rub(card.remaining))")
                        .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.textPrimary).monospacedDigit()
                }
            }
        }
    }

    private func controls(_ card: CorporateCard) -> some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: card.isFrozen ? "Разморозить карту" : "Заморозить карту",
                            icon: card.isFrozen ? "sun.max" : "snowflake") {
                store.setCardFrozen(!card.isFrozen, cardId: card.id)
            }
        }
    }
}
