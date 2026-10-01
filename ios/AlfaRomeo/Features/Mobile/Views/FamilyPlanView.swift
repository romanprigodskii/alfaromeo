import SwiftUI

/// Семейный пакет Ромео Mobile (§7.1 — семейный шеринг ГБ с профилями «Близкие»/детский).
///
/// Показывает общий пакет ГБ (сумма выделенного по участникам через ``MobileStore/familyAllocatedGb``
/// и израсходованного через ``MobileStore/familyUsedGb``), карточки участников с прогрессом и быстрым
/// перераспределением (``MobileStore/allocateGb(_:memberId:)``), и лист добавления нового участника
/// (``MobileStore/addFamilyMember(name:kind:allocatedGb:)``). Все мутации идут через общий store, поэтому
/// изменения мгновенно отражаются на хабе и других экранах модуля (единый источник правды).
struct FamilyPlanView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newKind: FamilyShareMember.Kind = .close
    @State private var newGb: Double = 5

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                sharedPool

                GroupedSection(
                    "Участники",
                    footer: "Общий пакет один на всю семью. ГБ можно распределить между близкими и детскими профилями."
                ) {
                    ForEach(store.family) { member in
                        memberRow(member)
                    }
                    Button { showAdd = true } label: {
                        HStack(spacing: ListRow.glyphSpacing) {
                            GlyphCircle(systemImage: "plus", tint: theme.accent)
                            Text("Добавить участника").font(BrandFont.bodyM).foregroundStyle(theme.accent)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Семейный пакет")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: store.familyAllocatedGb)
        .animation(reduceMotion ? nil : Motion.snappy, value: store.family.count)
        .task { await store.load(api: api, profileId: profileId) }
        .bottomSheet(isPresented: $showAdd) { addMemberSheet }
    }

    // MARK: - Общий пакет

    private var sharedPool: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Общий пакет").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Spacer(minLength: Spacing.sm)
                    Text(membersLabel).font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                Text(gb(store.familyUsedGb) + " из " + gb(store.familyAllocatedGb))
                    .font(BrandFont.title2).monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                ProgressBar(value: store.familyAllocatedGb > 0
                            ? min(1, store.familyUsedGb / store.familyAllocatedGb) : 0)
            }
        }
    }

    private var membersLabel: String {
        let n = store.family.count
        let (mod10, mod100) = (n % 10, n % 100)
        let word = mod10 == 1 && mod100 != 11 ? "участник"
            : (2...4).contains(mod10) && !(12...14).contains(mod100) ? "участника" : "участников"
        return MoneyFormat.integer(n) + "\u{00A0}" + word
    }

    private func gb(_ value: Double) -> String { MobileTariff.format(value) + "\u{00A0}ГБ" }

    // MARK: - Участник

    private func memberRow(_ member: FamilyShareMember) -> some View {
        let remaining = MobileTariff.format(member.remainingGb) + " из " + gb(member.allocatedGb)
        let subtitle = member.kind == .me ? "Осталось " + remaining
                                          : member.kind.label + ", осталось " + remaining
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: ListRow.glyphSpacing) {
                if member.kind == .me {
                    Avatar(initials: member.initials, size: ListRow.glyphSize)
                } else {
                    Avatar(systemImage: member.kind.icon, size: ListRow.glyphSize)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ProgressBar(value: member.usedFraction, height: 4)
                Stepper(
                    "Выделено: " + gb(member.allocatedGb),
                    value: Binding(
                        get: { member.allocatedGb },
                        set: { store.allocateGb($0, memberId: member.id) }
                    ),
                    in: 0...50,
                    step: 1
                )
                .font(BrandFont.callout)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .tint(theme.accent)
            }
            .padding(.leading, ListRow.glyphSize + ListRow.glyphSpacing)
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    // MARK: - Добавить участника

    private var addMemberSheet: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Новый участник").font(BrandFont.title1).foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Тип профиля").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                Picker("Тип профиля", selection: $newKind) {
                    ForEach([FamilyShareMember.Kind.close, .child], id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Имя").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                TextField("Например, Артём", text: $newName)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .padding(Spacing.md)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Выделить ГБ").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(gb(newGb)).font(BrandFont.headline).monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                }
                Slider(value: $newGb, in: 1...30, step: 1).tint(theme.accent)
            }

            PrimaryButton(title: "Добавить") {
                store.addFamilyMember(name: newName, kind: newKind, allocatedGb: newGb)
                resetForm()
                showAdd = false
            }
        }
    }

    private func resetForm() {
        newName = ""
        newKind = .close
        newGb = 5
    }
}

// MARK: - Preview

private struct FamilyPlanPreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            FamilyPlanView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Семейный пакет") {
    FamilyPlanPreviewHost(session: .mockAuthenticated())
}
