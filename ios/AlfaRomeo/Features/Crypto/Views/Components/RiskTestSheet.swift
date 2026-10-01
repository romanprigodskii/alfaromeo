import SwiftUI

/// «Тест на риски» — the gate before a неквал investor's first crypto trade (§2.4 / §10.8). Crypto
/// only: ЦФА never presents this. Passing requires ``CryptoRiskTest/passThreshold`` correct answers;
/// on pass it calls `onPass` (the caller marks the store and continues). Soft, re-takeable, no dead end.
struct RiskTestSheet: View {
    var onPass: () -> Void
    var onCancel: () -> Void

    @Environment(\.theme) private var theme
    @State private var answers: [Int: Int] = [:]
    @State private var result: Result? = nil

    private enum Result { case passed, failed(score: Int) }
    private let questions = CryptoRiskTest.questions

    private var allAnswered: Bool { answers.count == questions.count }
    private var score: Int { questions.filter { answers[$0.id] == $0.correctIndex }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(questions) { question in
                        questionBlock(question)
                    }
                }
                .padding(.bottom, Spacing.md)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Тест на риски").font(BrandFont.title1).foregroundStyle(theme.textPrimary)
            Text("\(questions.count) вопроса перед первой крипто-сделкой. Обязателен для неквалифицированных инвесторов, ЦФА не касается.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func questionBlock(_ q: RiskTestQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(q.prompt).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            ForEach(Array(q.options.enumerated()), id: \.offset) { index, option in
                optionRow(q: q, index: index, option: option)
            }
        }
    }

    private func optionRow(q: RiskTestQuestion, index: Int, option: String) -> some View {
        let selected = answers[q.id] == index
        return Button {
            answers[q.id] = index
            result = nil
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(selected ? theme.accent : theme.textSecondary)
                Text(option).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.rowVertical)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var footer: some View {
        if case .failed(let s) = result {
            Text("Правильно \(s) из \(questions.count). Нужно минимум \(CryptoRiskTest.passThreshold). Проверьте ответы и попробуйте снова.")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.statusInk(.danger))
                .fixedSize(horizontal: false, vertical: true)
        }
        PrimaryButton(title: "Пройти тест") {
            if score >= CryptoRiskTest.passThreshold {
                result = .passed
                onPass()
            } else {
                result = .failed(score: score)
            }
        }
        .disabled(!allAnswered)
        SecondaryButton(title: "Позже") { onCancel() }
    }
}

#Preview {
    RiskTestSheet(onPass: {}, onCancel: {})
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
