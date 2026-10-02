import XCTest
@testable import AlfaRomeo

/// docs/DESIGN.md §6: NBSP grouping, decimal comma, U+2212 minus, fiat 0 or 2 decimals.
final class MoneyFormatTests: XCTestCase {
    /// Writes expectations with ordinary spaces; the formatter must emit NBSP everywhere.
    private func nb(_ s: String) -> String { s.replacingOccurrences(of: " ", with: "\u{00A0}") }

    func testFiatWholeHasNoDecimals() {
        XCTAssertEqual(MoneyFormat.fiat(12_400), nb("12 400 ₽"))
        XCTAssertEqual(MoneyFormat.fiat(99.999), nb("100 ₽"))
    }

    func testFiatFractionHasExactlyTwoDecimals() {
        XCTAssertEqual(MoneyFormat.fiat(1_119_200.5), nb("1 119 200,50 ₽"))
        XCTAssertEqual(MoneyFormat.fiat(0.1 + 0.2), nb("0,30 ₽"))
    }

    func testOutputIsLocaleFreeNBSPAndComma() {
        let text = MoneyFormat.fiat(1_234_567.89)
        XCTAssertFalse(text.contains(" "), "plain space leaked: \(text)")
        XCTAssertFalse(text.contains("."), "decimal dot leaked: \(text)")
        XCTAssertEqual(text, nb("1 234 567,89 ₽"))
    }

    func testNegativeUsesUnicodeMinus() {
        let text = MoneyFormat.fiat(-1_240.5)
        XCTAssertEqual(text, nb("\u{2212}1 240,50 ₽"))
        XCTAssertFalse(text.contains("-"))
    }

    func testValueThatRoundsToZeroHasNoSign() {
        XCTAssertEqual(MoneyFormat.fiat(-0.004), nb("0 ₽"))
        XCTAssertEqual(MoneyFormat.signed(0), nb("0 ₽"))
    }

    func testSignedAmounts() {
        XCTAssertEqual(MoneyFormat.signed(12_400), nb("+12 400 ₽"))
        XCTAssertEqual(MoneyFormat.signed(-5), nb("\u{2212}5 ₽"))
        XCTAssertEqual(MoneyFormat.fiat(-5, sign: .never), nb("5 ₽"))
    }

    func testCurrencySymbols() {
        XCTAssertEqual(MoneyFormat.fiat(100, currency: "USD"), nb("100 $"))
        XCTAssertEqual(MoneyFormat.fiat(1, currency: "eur"), nb("1 €"))
        XCTAssertEqual(MoneyFormat.fiat(5, currency: ""), "5")
        XCTAssertEqual(MoneyFormat.symbol(for: "DRUB"), "Ц₽")
        XCTAssertEqual(MoneyFormat.symbol(for: "USDT"), "USDT")
    }

    func testAmountRoutesCryptoAndStablecoins() {
        XCTAssertEqual(MoneyFormat.amount(0.1423, currency: "btc"), nb("0,1423 BTC"))
        XCTAssertEqual(MoneyFormat.amount(10.5, currency: "USDT"), nb("10,50 USDT"))
    }

    func testCryptoTrimsTrailingZeros() {
        XCTAssertEqual(MoneyFormat.crypto(12.5, symbol: "ETH"), nb("12,5 ETH"))
        XCTAssertEqual(MoneyFormat.crypto(1, symbol: "BTC"), nb("1 BTC"))
        XCTAssertEqual(MoneyFormat.crypto(0.123456789), "0,12345679")
        XCTAssertEqual(MoneyFormat.crypto(-0.5, symbol: "SOL", sign: .always), nb("\u{2212}0,5 SOL"))
    }

    func testPercent() {
        XCTAssertEqual(MoneyFormat.percent(-0.74), nb("\u{2212}0,74 %"))
        XCTAssertEqual(MoneyFormat.percent(26), nb("26 %"))
        XCTAssertEqual(MoneyFormat.percent(19.9), nb("19,9 %"))
        XCTAssertEqual(MoneyFormat.percent(fraction: 0.199), nb("19,9 %"))
        XCTAssertEqual(MoneyFormat.percent(0.5, sign: .always), nb("+0,5 %"))
        XCTAssertEqual(MoneyFormat.percent(5, minFractionDigits: 1), nb("5,0 %"))
    }

    func testCompact() {
        XCTAssertEqual(MoneyFormat.compact(2_200_000), nb("2,2 млн ₽"))
        XCTAssertEqual(MoneyFormat.compact(2_000_000), nb("2 млн ₽"))
        XCTAssertEqual(MoneyFormat.compact(840_000), nb("840 тыс. ₽"))
        XCTAssertEqual(MoneyFormat.compact(1_500_000_000), nb("1,5 млрд ₽"))
        XCTAssertEqual(MoneyFormat.compact(-2_200_000), nb("\u{2212}2,2 млн ₽"))
        XCTAssertEqual(MoneyFormat.compact(9_999), nb("9 999 ₽"))
        XCTAssertEqual(MoneyFormat.compact(12_345, currency: nil), nb("12,3 тыс."))
    }

    /// Regression: values just under a unit boundary rounded up to «1 000 тыс. ₽» / «1 000 млн ₽».
    func testCompactPromotesAtRoundingEdge() {
        XCTAssertEqual(MoneyFormat.compact(999_999), nb("1 млн ₽"))
        XCTAssertEqual(MoneyFormat.compact(999_600_000), nb("1 млрд ₽"))
        XCTAssertEqual(MoneyFormat.compact(999_499), nb("999 тыс. ₽"))
    }

    func testHeroParts() {
        let big = MoneyFormat.parts(1_119_200.5)
        XCTAssertEqual(big.integer, nb("1 119 200"))
        XCTAssertEqual(big.fraction, ",50")
        let whole = MoneyFormat.parts(12_400)
        XCTAssertEqual(whole.integer, nb("12 400"))
        XCTAssertNil(whole.fraction)
        XCTAssertEqual(MoneyFormat.parts(-5.5).integer, "\u{2212}5")
    }

    func testIntegerAndNumber() {
        XCTAssertEqual(MoneyFormat.integer(-1_500), nb("\u{2212}1 500"))
        XCTAssertEqual(MoneyFormat.integer(24), "24")
        XCTAssertEqual(MoneyFormat.number(1_234.5), nb("1 234,5"))
        XCTAssertFalse(MoneyFormat.fiat(.nan).lowercased().contains("nan"))
    }
}
