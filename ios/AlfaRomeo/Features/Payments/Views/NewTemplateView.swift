import SwiftUI

/// Создание шаблона / автоплатежа (§9.2 — облегчённо). A light form: тип, название, направление
/// (rail), сумма, и расписание (для автоплатежа). Saving is a demo confirmation, then pops back.
struct NewTemplateView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    enum Mode: String, CaseIterable, Identifiable { case template, autopayment
        var id: String { rawValue }
        var label: String { self == .template ? "Шаблон" : "Автоплатёж" }
    }

    @State private var mode: Mode = .template
    @State private var name = ""
    @State private var kind: TransferKind = .byPhone
    @State private var amount = ""
    @State private var schedule: Autopayment.Schedule = .monthly
    @State private var saved = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                labeled("Название") {
                    field($name, placeholder: mode == .template ? "Например, «Маме на телефон»" : "Например, «Подписка»")
                }

                labeled("Направление") {
                    Menu {
                        ForEach(TransferKind.allCases) { k in
                            Button { kind = k } label: { Label(k.title, systemImage: k.icon) }
                        }
                    } label: { menuLabel(icon: kind.icon, text: kind.title) }
                }

                labeled("Сумма (необязательно)") {
                    field($amount, placeholder: "0", keyboard: .decimalPad, mono: true)
                }

                if mode == .autopayment {
                    labeled("Расписание") {
                        Menu {
                            ForEach(Autopayment.Schedule.allCases, id: \.self) { s in
                                Button(s.label) { schedule = s }
                            }
                        } label: { menuLabel(icon: "calendar", text: schedule.label) }
                    }
                }

                if saved {
                    StatusPill(status: .success, text: "\(mode.label) сохранён (демо)")
                }

                PrimaryButton(title: "Сохранить", icon: "checkmark") {
                    withAnimation(Motion.snappy) { saved = true }
                    Task {
                        try? await Task.sleep(for: .seconds(0.9))
                        router.pop()
                    }
                }
                .disabled(!canSave || saved)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новый \(mode == .template ? "шаблон" : "автоплатёж")")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.smooth, value: mode)
    }

    // MARK: Helpers

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased()).font(BrandFont.micro).tracking(1).foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func menuLabel(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.accent)
            Text(text).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.md)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func field(_ binding: Binding<String>, placeholder: String = "",
                       keyboard: UIKeyboardType = .default, mono: Bool = false) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(keyboard)
            .font(mono ? BrandFont.mono(17) : BrandFont.body())
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }
}
