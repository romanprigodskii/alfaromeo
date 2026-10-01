import SwiftUI

/// Add an employee (§8.2) — a mock invite: name, email, role. Persists into ``TeamStore`` and pops.
struct AddMemberView: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared

    @State private var name = ""
    @State private var email = ""
    @State private var role: MembershipRole = .manager

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                field("Имя и фамилия", text: $name)
                field("Email", text: $email, keyboard: .emailAddress)
                rolePicker
                PrimaryButton(title: "Пригласить (демо)", icon: "paperplane.fill") {
                    store.addMember(name: name, role: role, email: email)
                    router.pop()
                }
                .disabled(!canAdd)
                Text("В демо сотрудник добавляется сразу. В реальном банке он получит приглашение по email или SMS и пройдёт проверку.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Новый сотрудник")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        Text("Выберите роль, права назначатся автоматически.")
            .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Роль").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            VStack(spacing: Spacing.sm) {
                ForEach(RoleCatalog.demoRoles, id: \.self) { r in
                    Button { role = r } label: { roleOption(r) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func roleOption(_ r: MembershipRole) -> some View {
        let selected = r == role
        return HStack(spacing: Spacing.md) {
            GlyphCircle(systemImage: RoleCatalog.icon(r),
                        tint: selected ? theme.onAccent : nil,
                        background: selected ? theme.accent : nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(RoleCatalog.label(r)).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(RoleCatalog.blurb(r)).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selected ? theme.accent : theme.textSecondary.opacity(0.5))
        }
        .padding(Spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            .stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 1.5 : 1))
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .font(BrandFont.body())
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }
}
