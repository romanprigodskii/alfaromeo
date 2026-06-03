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
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Карта не найдена").font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.lg)
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
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: [BrandColors.bizElevatedDark, BrandColors.bizSurfaceDark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 188)
                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1))
            VStack(alignment: .leading) {
                HStack {
                    Text(card.holderName).font(BrandFont.headline).foregroundStyle(.white)
                    Spacer()
                    Text(card.kind.label).font(BrandFont.micro.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("•••• •••• •••• \(card.last4)")
                    .font(BrandFont.mono(20, weight: .medium)).foregroundStyle(.white)
                    .monospacedDigit()
                HStack {
                    Text(store.member(id: card.holderUserId).map { RoleCatalog.label($0.role) } ?? "Сотрудник")
                        .font(BrandFont.caption).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if card.isFrozen {
                        Label("Заморожена", systemImage: "snowflake")
                            .font(BrandFont.micro.weight(.semibold)).foregroundStyle(.white)
                    }
                    Text("МИР").font(BrandFont.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(Spacing.lg)
            .frame(height: 188)
        }
        .opacity(card.isFrozen ? 0.7 : 1)
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
