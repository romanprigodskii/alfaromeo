import SwiftUI

/// Issue a corporate card to an employee (§8.2): pick holder, type, monthly limit → mock issue. The
/// holder may be preset (entered from a member's detail).
struct IssueCorpCardView: View {
    let presetMemberId: String?

    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared

    @State private var holderId: String = ""
    @State private var kind: CorporateCard.Kind = .virtual
    @State private var limitText = "100000"

    private var canIssue: Bool { !holderId.isEmpty && SupplierPaymentModel.parse(limitText) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                holderPicker
                typePicker
                limitField
                PrimaryButton(title: "Выпустить карту", icon: "creditcard.and.123") {
                    store.issueCorpCard(toUserId: holderId, kind: kind,
                                        monthlyLimit: SupplierPaymentModel.parse(limitText))
                    router.pop()
                }
                .disabled(!canIssue)
                Text("Виртуальная выпускается мгновенно (§6.2). Пластик — с доставкой. Лимит можно менять в карточке.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Выпуск карты")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if holderId.isEmpty {
                holderId = presetMemberId ?? store.members.first(where: { !$0.isCurrentUser })?.id
                    ?? store.members.first?.id ?? ""
            }
        }
    }

    private var holderPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Сотрудник").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
                        if index > 0 { Divider().overlay(theme.border) }
                        Button { holderId = member.id } label: {
                            HStack(spacing: Spacing.md) {
                                Avatar(initials: member.initials, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(member.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                                    Text(member.roleLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: holderId == member.id ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(holderId == member.id ? theme.accent : theme.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Тип карты").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            Picker("", selection: $kind) {
                ForEach(CorporateCard.Kind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var limitField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Месячный лимит, ₽").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            TextField("100 000", text: $limitText)
                .keyboardType(.numberPad)
                .font(BrandFont.mono(20, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity)
                .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
            HStack(spacing: Spacing.sm) {
                ForEach([50_000.0, 100_000.0, 300_000.0], id: \.self) { v in
                    Button { limitText = String(Int(v)) } label: {
                        Text("\(Int(v / 1000)) тыс")
                            .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.accent)
                            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                            .background(theme.accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
