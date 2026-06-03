import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Real document generation for История (§9.4 / §10.7 «чек», «экспорт PDF/CSV»). Produces files on
/// disk (temporary directory) and returns their `URL`s, ready to hand to a share sheet. No backend —
/// everything is rendered client-side from the session's operations.
enum HistoryDocuments {

    /// One row of an exported statement, pre-resolved (category already applied) for rendering.
    struct StatementRow: Identifiable {
        let id: String
        let date: Date?
        let counterparty: String
        let category: String
        let amount: Double
        let currency: String
        let status: String
    }

    // MARK: - ISO timestamp (matches the contract's `createdAt` format)

    static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }
    private static let isoFormatter = ISO8601DateFormatter()

    // MARK: - Formatting helpers

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    private static func money(_ value: Double, _ currency: String) -> String {
        let symbol = currency == "RUB" ? "₽" : currency
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        let n = amountFormatter.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        return "\(sign)\(n) \(symbol)"
    }

    private static func dateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return "\(HistoryFormatting.dayMonth(date)), \(HistoryFormatting.time(date))"
    }

    // MARK: - CSV (pure Foundation)

    /// A semicolon-separated statement (RU-Excel friendly) written UTF-8 **with BOM** so Cyrillic and
    /// the ₽/− glyphs open correctly in Excel. Amount is a raw signed number for spreadsheet math.
    static func statementCSV(periodLabel: String, rows: [StatementRow]) -> URL? {
        var lines = ["Дата;Время;Получатель;Категория;Статус;Сумма;Валюта"]
        for r in rows {
            let day = r.date.map(HistoryFormatting.dayMonth) ?? ""
            let time = r.date.map(HistoryFormatting.time) ?? ""
            let amount = String(format: "%.2f", r.amount)
            lines.append([day, time, csv(r.counterparty), csv(r.category), csv(r.status), amount, r.currency]
                .joined(separator: ";"))
        }
        let bom = "\u{FEFF}"
        let body = bom + lines.joined(separator: "\r\n") + "\r\n"
        return write(body.data(using: .utf8), name: "Выписка-\(slug(periodLabel)).csv")
    }

    /// Escape a CSV field: wrap in quotes if it contains a separator/quote/newline, doubling quotes.
    private static func csv(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - PDF

    #if canImport(UIKit)
    private static let pageSize = CGSize(width: 595.2, height: 841.8)   // A4 @ 72dpi
    private static let margin: CGFloat = 48
    private static let brandRed = UIColor(red: 0xE2/255, green: 0x12/255, blue: 0x0F/255, alpha: 1)
    private static let ink = UIColor(white: 0.10, alpha: 1)
    private static let muted = UIColor(white: 0.42, alpha: 1)

    /// A single-page electronic receipt for one operation (§9.4 «чек»).
    static func receiptPDF(for tx: Transaction, categoryTitle: String, accountTitle: String) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y = margin + 8
            drawBrandHeader(subtitle: "Электронный чек", y: &y)

            let merchant = tx.counterparty ?? categoryTitle
            draw(merchant, x: margin, y: &y, font: .boldSystemFont(ofSize: 22), color: ink, gapAfter: 6)

            let positive = tx.amount > 0
            let amountColor = positive ? UIColor(red: 0.12, green: 0.56, blue: 0.24, alpha: 1)
                                       : UIColor(red: 0.75, green: 0.23, blue: 0.17, alpha: 1)
            draw(money(tx.amount, tx.currency), x: margin, y: &y,
                 font: .boldSystemFont(ofSize: 30), color: amountColor, gapAfter: 22)

            line(y: &y)

            var pairs: [(String, String)] = [
                ("Дата и время", dateTime(HistoryFormatting.date(tx.createdAt))),
                ("Категория", categoryTitle),
                ("Тип операции", kindLabel(tx.kind)),
                ("Счёт", accountTitle),
                ("Статус", statusLabel(tx.status)),
            ]
            if let fee = tx.fee, fee > 0 { pairs.append(("Комиссия", money(-fee, tx.currency))) }
            pairs.append(("ID операции", tx.id))
            for (label, value) in pairs { drawRow(label: label, value: value, y: &y) }

            drawFooter()
        }
        return write(data, name: "Чек-\(slug(tx.id)).pdf")
    }

    /// A multi-page statement over a set of operations (§9.4 «отчёты/экспорт»).
    static func statementPDF(periodLabel: String, rows: [StatementRow]) -> URL? {
        let income = rows.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = rows.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y = margin + 8
            drawBrandHeader(subtitle: "Выписка по операциям", y: &y)
            draw("Период: \(periodLabel) · операций: \(rows.count)", x: margin, y: &y,
                 font: .systemFont(ofSize: 12), color: muted, gapAfter: 16)
            drawTableHeader(y: &y)

            for r in rows {
                if y > pageSize.height - margin - 90 {     // leave room for the footer / totals
                    drawFooter(); ctx.beginPage(); y = margin + 8; drawTableHeader(y: &y)
                }
                drawStatementRow(r, y: &y)
            }

            y += 8; line(y: &y); y += 6
            drawTotals(income: income, expense: expense, y: &y)
            drawFooter()
        }
        return write(data, name: "Выписка-\(slug(periodLabel)).pdf")
    }

    // MARK: - PDF drawing primitives

    private static func drawBrandHeader(subtitle: String, y: inout CGFloat) {
        draw("Альфа·Ромео", x: margin, y: &y, font: .boldSystemFont(ofSize: 20), color: brandRed, gapAfter: 4)
        draw(subtitle, x: margin, y: &y, font: .systemFont(ofSize: 14), color: muted, gapAfter: 10)
        line(y: &y); y += 14
    }

    private static func draw(_ text: String, x: CGFloat, y: inout CGFloat, font: UIFont,
                             color: UIColor, gapAfter: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        y += font.lineHeight + gapAfter
    }

    private static func drawRow(label: String, value: String, y: inout CGFloat) {
        let labelFont = UIFont.systemFont(ofSize: 12)
        let valueFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        (label as NSString).draw(at: CGPoint(x: margin, y: y),
                                 withAttributes: [.font: labelFont, .foregroundColor: muted])
        let para = NSMutableParagraphStyle(); para.alignment = .right
        let rect = CGRect(x: margin, y: y - 1, width: pageSize.width - 2 * margin, height: 18)
        (value as NSString).draw(in: rect, withAttributes: [.font: valueFont, .foregroundColor: ink,
                                                            .paragraphStyle: para])
        y += 30
    }

    private static func drawTableHeader(y: inout CGFloat) {
        let f = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let cols = ["ДАТА", "ПОЛУЧАТЕЛЬ", "КАТЕГОРИЯ"]
        let xs: [CGFloat] = [margin, margin + 110, margin + 300]
        for (c, x) in zip(cols, xs) {
            (c as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: f, .foregroundColor: muted])
        }
        let para = NSMutableParagraphStyle(); para.alignment = .right
        ("СУММА" as NSString).draw(in: CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: 14),
                                   withAttributes: [.font: f, .foregroundColor: muted, .paragraphStyle: para])
        y += 22; line(y: &y); y += 8
    }

    private static func drawStatementRow(_ r: StatementRow, y: inout CGFloat) {
        let f = UIFont.systemFont(ofSize: 11)
        (dateTime(r.date) as NSString).draw(in: CGRect(x: margin, y: y, width: 105, height: 14),
                                            withAttributes: [.font: f, .foregroundColor: ink])
        (clip(r.counterparty, 24) as NSString).draw(in: CGRect(x: margin + 110, y: y, width: 185, height: 14),
                                                    withAttributes: [.font: f, .foregroundColor: ink])
        (clip(r.category, 16) as NSString).draw(in: CGRect(x: margin + 300, y: y, width: 120, height: 14),
                                                withAttributes: [.font: f, .foregroundColor: muted])
        let para = NSMutableParagraphStyle(); para.alignment = .right
        let color = r.amount >= 0 ? UIColor(red: 0.12, green: 0.56, blue: 0.24, alpha: 1) : ink
        (money(r.amount, r.currency) as NSString).draw(
            in: CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: 14),
            withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium),
                             .foregroundColor: color, .paragraphStyle: para])
        y += 20
    }

    private static func drawTotals(income: Double, expense: Double, y: inout CGFloat) {
        drawRow(label: "Поступления", value: money(income, "RUB"), y: &y)
        drawRow(label: "Списания", value: money(-expense, "RUB"), y: &y)
        drawRow(label: "Итого", value: money(income - expense, "RUB"), y: &y)
    }

    private static func line(y: inout CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke(); path.lineWidth = 0.7; path.stroke()
    }

    private static func drawFooter() {
        let f = UIFont.systemFont(ofSize: 9)
        let text = "Сформировано в приложении Альфа-Ромео · демонстрационный документ"
        (text as NSString).draw(at: CGPoint(x: margin, y: pageSize.height - margin + 6),
                                withAttributes: [.font: f, .foregroundColor: muted])
    }

    private static func clip(_ s: String, _ max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }
    #endif

    // MARK: - Shared helpers

    private static func kindLabel(_ kind: TransactionKind) -> String {
        switch kind {
        case .transfer: return "Перевод"
        case .payment:  return "Платёж"
        case .convert:  return "Конвертация"
        case .trade:    return "Сделка"
        case .payout:   return "Зачисление"
        case .acquire:  return "Эквайринг"
        }
    }
    private static func statusLabel(_ status: TransactionStatus) -> String {
        switch status {
        case .completed:         return "Выполнено"
        case .processing:        return "Обработка"
        case .pending:           return "В ожидании"
        case .failed, .declined: return "Отклонено"
        }
    }

    private static func slug(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let mapped = s.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(mapped).replacingOccurrences(of: "--", with: "-")
    }

    private static func write(_ data: Data?, name: String) -> URL? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
}
