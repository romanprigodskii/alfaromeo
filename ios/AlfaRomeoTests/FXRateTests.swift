import XCTest
@testable import AlfaRomeo

/// ЦБ daily_json parsing (`Value / Nominal`) on a fixed fixture, plus the rate book's invariants.
final class FXRateTests: XCTestCase {
    private static let fixture = """
    {
      "Date": "2026-10-02T11:30:00+03:00",
      "PreviousDate": "2026-10-01T11:30:00+03:00",
      "Timestamp": "2026-10-01T20:00:00+03:00",
      "Valute": {
        "USD": {"ID": "R01235", "NumCode": "840", "CharCode": "USD", "Nominal": 1, "Name": "Доллар США", "Value": 83.2454, "Previous": 83.5588},
        "KZT": {"ID": "R01335", "NumCode": "398", "CharCode": "KZT", "Nominal": 100, "Name": "Казахстанских тенге", "Value": 18.8825, "Previous": 18.95},
        "JPY": {"ID": "R01820", "NumCode": "392", "CharCode": "JPY", "Nominal": 100, "Name": "Японских иен", "Value": 52.637, "Previous": 52.1},
        "AMD": {"ID": "R01060", "NumCode": "051", "CharCode": "AMD", "Nominal": 100, "Name": "Армянских драмов", "Value": 22.944},
        "XDR": {"ID": "R01589", "NumCode": "960", "CharCode": "XDR", "Nominal": 0, "Name": "СДР", "Value": 110.0, "Previous": 110.0},
        "BAD": {"ID": "R00000", "NumCode": "000", "CharCode": "BAD", "Nominal": 1, "Name": "Битая строка", "Value": 0, "Previous": 1}
      }
    }
    """

    private let host = "www.cbr-xml-daily.ru"

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func table(_ json: String = FXRateTests.fixture, status: Int = 200) async throws -> CBRTable {
        StubURLProtocol.stub(host: host, status: status, json: json)
        return try await FxRateClient(session: StubURLProtocol.session()).cbrTable()
    }

    func testNominalIsDividedOut() async throws {
        let t = try await table()
        XCTAssertEqual(t.quotes["USD"]?.perUnit ?? 0, 83.2454, accuracy: 1e-12)
        XCTAssertEqual(t.quotes["KZT"]?.perUnit ?? 0, 0.188825, accuracy: 1e-12)
        XCTAssertEqual(t.quotes["KZT"]?.previousPerUnit ?? 0, 0.1895, accuracy: 1e-12)
        XCTAssertEqual(t.quotes["JPY"]?.perUnit ?? 0, 0.52637, accuracy: 1e-12)
        XCTAssertEqual(t.quotes["KZT"]?.name, "Казахстанских тенге")
    }

    func testDayChangeAndMissingPrevious() async throws {
        let t = try await table()
        XCTAssertEqual(t.quotes["USD"]?.changePct ?? 0, -0.375065, accuracy: 1e-6)
        XCTAssertNotNil(t.quotes["AMD"])
        XCTAssertNil(t.quotes["AMD"]?.previousPerUnit)
        XCTAssertNil(t.quotes["AMD"]?.changePct)
    }

    func testZeroNominalOrValueRowsAreDropped() async throws {
        let t = try await table()
        XCTAssertNil(t.quotes["XDR"])
        XCTAssertNil(t.quotes["BAD"])
        XCTAssertEqual(Set(t.quotes.keys), ["USD", "KZT", "JPY", "AMD"])
        XCTAssertEqual(t.date, ISO8601DateFormatter().date(from: "2026-10-02T11:30:00+03:00"))
    }

    func testPayloadWithoutPlausibleUSDIsRejected() async {
        let noUSD = FXRateTests.fixture.replacingOccurrences(of: "\"USD\": {", with: "\"EUR\": {")
        let silly = FXRateTests.fixture.replacingOccurrences(of: "\"Value\": 83.2454", with: "\"Value\": 8324.54")
        for json in [noUSD, silly] {
            do { _ = try await table(json); XCTFail("accepted a table without a plausible USD") } catch {}
        }
        do { _ = try await table(status: 500); XCTFail("accepted HTTP 500") } catch {}
    }

    func testSeedTableIsNormalised() {
        let seed = FxRateClient.seedTable
        XCTAssertTrue(seed.quotes.values.allSatisfy { $0.perUnit > 0 })
        XCTAssertLessThan(seed.quotes["KZT"]?.perUnit ?? 1, 1)
        XCTAssertEqual(FxRateClient.fallbackRate, seed.quotes["USD"]?.perUnit)
    }

    @MainActor
    func testRateBookInvariants() {
        let fx = FXRateService.shared
        XCTAssertEqual(fx.rate("RUB"), 1)
        XCTAssertEqual(fx.rate("rub"), 1)
        XCTAssertEqual(fx.rate("ZZZ"), 1, "unknown code must never value at 0")
        XCTAssertTrue(fx.isFiat("usd"))
        XCTAssertFalse(fx.isFiat("BTC"))
        XCTAssertEqual(fx.convert(1_000, from: "USD", to: "USD"), 1_000, accuracy: 1e-9)
        XCTAssertEqual(fx.convert(250, from: "EUR", to: "RUB"), 250 * fx.rate("EUR"), accuracy: 1e-9)
        XCTAssertEqual(fx.convert(fx.rate("USD"), from: "RUB", to: "USD"), 1, accuracy: 1e-12)
        let text = fx.rateText("USD")
        XCTAssertTrue(text.hasPrefix("1 USD = ") && text.hasSuffix("\u{00A0}₽") && text.contains(","), text)
    }
}
