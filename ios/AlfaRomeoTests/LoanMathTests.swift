import XCTest
@testable import AlfaRomeo

/// §10.5: one annuity core drives the payment, the schedule and the inverse pre-qual limit.
final class LoanMathTests: XCTestCase {
    func testAnnuityKnownValues() {
        XCTAssertEqual(LoanMath.monthlyPayment(principal: 1_000_000, annualRatePercent: 12, months: 12),
                       88_848.79, accuracy: 0.01)
        XCTAssertEqual(LoanMath.monthlyPayment(principal: 500_000, annualRatePercent: 19.9, months: 60),
                       13_219.14, accuracy: 0.01)
    }

    func testZeroRateIsStraightLine() {
        XCTAssertEqual(LoanMath.monthlyPayment(principal: 120_000, annualRatePercent: 0, months: 12), 10_000)
        XCTAssertEqual(LoanMath.maxPrincipal(payment: 10_000, annualRatePercent: 0, months: 12), 120_000)
        XCTAssertEqual(LoanMath.overpay(principal: 120_000, annualRatePercent: 0, months: 12), 0, accuracy: 1e-9)
    }

    func testDegenerateInputIsZero() {
        XCTAssertEqual(LoanMath.monthlyPayment(principal: 0, annualRatePercent: 20, months: 12), 0)
        XCTAssertEqual(LoanMath.monthlyPayment(principal: 100_000, annualRatePercent: 20, months: 0), 0)
        XCTAssertEqual(LoanMath.maxPrincipal(payment: -1, annualRatePercent: 20, months: 12), 0)
        XCTAssertTrue(LoanMath.schedule(principal: 100_000, annualRatePercent: 20, months: 0).isEmpty)
    }

    func testInverseRoundTrips() {
        for (principal, rate, months) in [(750_000.0, 25.9, 36), (2_000_000.0, 14.5, 84), (50_000.0, 0.0, 6)] {
            let payment = LoanMath.monthlyPayment(principal: principal, annualRatePercent: rate, months: months)
            XCTAssertEqual(LoanMath.maxPrincipal(payment: payment, annualRatePercent: rate, months: months),
                           principal, accuracy: 1e-6)
        }
    }

    func testScheduleAmortisesToZero() {
        let principal = 1_000_000.0
        let rows = LoanMath.schedule(principal: principal, annualRatePercent: 12, months: 12)
        XCTAssertEqual(rows.count, 12)
        XCTAssertEqual(rows.first?.interestPart ?? 0, 10_000, accuracy: 1e-9)   // 1 % of the full balance
        XCTAssertEqual(rows.last?.balance, 0)
        XCTAssertEqual(rows.map(\.principalPart).reduce(0, +), principal, accuracy: 1e-6)
        XCTAssertEqual(rows.map(\.payment).reduce(0, +),
                       LoanMath.totalPaid(principal: principal, annualRatePercent: 12, months: 12), accuracy: 1e-6)
        XCTAssertTrue(zip(rows, rows.dropFirst()).allSatisfy { $0.balance > $1.balance })
    }

    func testOverpayIsTotalMinusPrincipal() {
        let total = LoanMath.totalPaid(principal: 1_000_000, annualRatePercent: 12, months: 12)
        XCTAssertEqual(LoanMath.overpay(principal: 1_000_000, annualRatePercent: 12, months: 12),
                       total - 1_000_000, accuracy: 1e-9)
        XCTAssertEqual(total, 1_066_185.46, accuracy: 0.01)
    }
}
