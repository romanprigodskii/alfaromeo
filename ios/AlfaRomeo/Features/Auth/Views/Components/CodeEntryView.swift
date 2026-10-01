import SwiftUI

/// Reusable fixed-length numeric code entry rendered as cells, backed by a hidden field.
/// Used for OTP (`secure: false`) and PIN (`secure: true`).
struct CodeEntryView: View {
    @Binding var code: String
    var length: Int = 4
    var secure: Bool = false
    var autofocus: Bool = true

    @FocusState private var focused: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(secure ? nil : .oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(length))
                }

            HStack(spacing: Spacing.sm) {
                ForEach(0..<length, id: \.self) { index in
                    cell(index)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { if autofocus { focused = true } }
    }

    private func cell(_ index: Int) -> some View {
        let characters = Array(code)
        let isFilled = index < characters.count
        let isCursor = focused && index == characters.count
        let content = isFilled ? (secure ? "●" : String(characters[index])) : ""
        return Text(content)
            .font(BrandFont.mono(secure ? 15 : 22, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
            .frame(width: 52, height: 60)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                    .stroke(isCursor ? theme.accent : .clear, lineWidth: 1.5)
            )
    }
}
