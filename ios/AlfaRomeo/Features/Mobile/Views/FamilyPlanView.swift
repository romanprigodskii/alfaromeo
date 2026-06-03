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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                sharedPool

                ForEach(store.family) { member in
                    memberCard(member)
                }

                SecondaryButton(title: "Добавить участника", icon: "person.badge.plus") {
                    showAdd = true
                }

                Text("Распределяйте ГБ между близкими и детскими профилями — общий пакет один на всю семью (§7.1).")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
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
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.2.fill").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("Общий пакет").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(store.family.count) уч.").font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                ProgressBar(value: store.familyAllocatedGb > 0
                            ? min(1, store.familyUsedGb / store.familyAllocatedGb) : 0)
                Text("\(MobileTariff.format(store.familyUsedGb)) из \(MobileTariff.format(store.familyAllocatedGb)) ГБ распределено")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Участник

    private func memberCard(_ member: FamilyShareMember) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    if member.kind == .me {
                        Avatar(initials: member.initials)
                    } else {
                        Avatar(systemImage: member.kind.icon)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name).font(BrandFont.bodyM.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                        Badge(kind: .text(member.kind.label), tint: theme.accent)
                    }
                    Spacer()
                }

                ProgressBar(value: member.usedFraction)
                Text("\(MobileTariff.format(member.remainingGb)) ГБ осталось из \(MobileTariff.format(member.allocatedGb))")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)

                Divider().overlay(theme.border)

                Stepper(
                    "Выделено: \(Int(member.allocatedGb)) ГБ",
                    value: Binding(
                        get: { member.allocatedGb },
                        set: { store.allocateGb($0, memberId: member.id) }
                    ),
                    in: 0...50,
                    step: 1
                )
                .font(BrandFont.callout)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.accent)
            }
        }
    }

    // MARK: - Добавить участника

    private var addMemberSheet: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Новый участник").font(BrandFont.title).foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Тип профиля").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                Picker("Тип профиля", selection: $newKind) {
                    ForEach([FamilyShareMember.Kind.close, .child], id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Имя").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                TextField("Например, Артём", text: $newName)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .padding(Spacing.md)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(theme.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Выделить ГБ").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("\(Int(newGb)) ГБ").font(BrandFont.callout.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                Slider(value: $newGb, in: 1...30, step: 1).tint(theme.accent)
            }

            PrimaryButton(title: "Добавить", icon: "checkmark") {
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
