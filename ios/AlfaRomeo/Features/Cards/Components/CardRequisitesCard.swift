import SwiftUI
import UIKit
import LocalAuthentication

/// Card requisites with show/hide (§6.3). Masked by default; revealing asks Face ID or the device
/// passcode, then flips PAN / срок / CVC and lets the user copy the number. Hides itself after 30 s,
/// when the screen goes away or the app leaves the foreground. Demo values only: the real PAN never
/// leaves the server (§11.8).
struct CardRequisitesCard: View {
    let card: CardItem
    @Binding var revealed: Bool

    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var copied: String?
    @State private var authorizing = false

    private static let autoHideAfter: Duration = .seconds(30)

    private var req: CardRequisites { card.requisites }

    var body: some View {
        GroupedSection("Реквизиты",
                       actionTitle: revealed ? "Скрыть" : "Показать",
                       action: toggle,
                       footer: revealed ? "Демо-данные, не настоящие реквизиты." : nil) {
            row(label: "Номер карты",
                value: revealed ? req.fullPan : req.maskedPan,
                copyValue: revealed ? req.fullPan.replacingOccurrences(of: " ", with: "") : nil)

            HStack(spacing: Spacing.xl) {
                field(label: "Срок", value: revealed ? req.expiry : "••/••")
                field(label: "CVC", value: revealed ? req.cvv : "•••")
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.rowVertical)
        }
        .task(id: revealed) {
            guard revealed else { return }
            try? await Task.sleep(for: Self.autoHideAfter)
            guard !Task.isCancelled else { return }
            hide()
        }
        .onDisappear { revealed = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { hide() }
        }
    }

    // MARK: Reveal

    private func toggle() {
        if revealed { hide(); return }
        guard !authorizing else { return }
        authorizing = true
        Task {
            let ok = await Self.authenticate()
            authorizing = false
            if ok { withAnimation(Motion.snappy) { revealed = true } }
        }
    }

    private func hide() {
        guard revealed else { return }
        copied = nil
        withAnimation(Motion.snappy) { revealed = false }
    }

    /// Face ID / Touch ID with the passcode fallback. A device with neither set up (the simulator)
    /// has nothing to check against, so the reveal goes through there.
    private static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Ввести код устройства"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: "Показать реквизиты карты")
        } catch {
            return false
        }
    }

    private func row(label: String, value: String, copyValue: String?) -> some View {
        HStack {
            field(label: label, value: value)
            Spacer(minLength: Spacing.sm)
            if let copyValue {
                Button {
                    UIPasteboard.general.string = copyValue
                    withAnimation(Motion.snappy) { copied = label }
                } label: {
                    Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 17))
                        .foregroundStyle(copied == label ? theme.success : theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Скопировать \(label)")
            }
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private func field(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            Text(value)
                .font(BrandFont.code(17, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.identity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
