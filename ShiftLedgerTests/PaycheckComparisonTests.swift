import Foundation
import Testing
@testable import ShiftLedger

struct PaycheckComparisonTests {
    @Test("Одинаковые ожидаемая и фактическая суммы дают нулевую разницу")
    func calculatesExactMatch() throws {
        let expected = expectedGross(amount: Decimal(1_000))
        let actualGross = try ActualGross(amount: Decimal(1_000))
        let comparison = PaycheckComparison(expected: expected, actualGross: actualGross)

        #expect(comparison.expected == expected)
        #expect(comparison.actualGross == actualGross)
        #expect(comparison.difference == .zero)
    }

    @Test("Фактическая сумма меньше ожидаемой и даёт отрицательную разницу")
    func calculatesNegativeDifference() throws {
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: Decimal(1_000)),
            actualGross: try ActualGross(amount: Decimal(900))
        )

        #expect(comparison.difference == Decimal(-100))
    }

    @Test("Фактическая сумма больше ожидаемой и даёт положительную разницу")
    func calculatesPositiveDifference() throws {
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: Decimal(1_000)),
            actualGross: try ActualGross(amount: Decimal(1_100))
        )

        #expect(comparison.difference == Decimal(100))
    }

    @Test("Нулевая фактическая сумма участвует в сравнении")
    func comparesZeroActualGross() throws {
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: Decimal(1_000)),
            actualGross: try ActualGross(amount: .zero)
        )

        #expect(comparison.difference == Decimal(-1_000))
    }

    @Test("Нулевая ожидаемая сумма сохраняет положительную фактическую разницу")
    func comparesZeroExpectedGross() throws {
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: .zero),
            actualGross: try ActualGross(amount: Decimal(250))
        )

        #expect(comparison.difference == Decimal(250))
    }

    @Test("Отрицательная дробная разница сохраняется точно")
    func preservesFractionalNegativeDifference() throws {
        let expectedAmount = try decimal("1000.005")
        let expectedDifference = try decimal("-0.005")
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: expectedAmount),
            actualGross: try ActualGross(amount: Decimal(1_000))
        )

        #expect(comparison.difference == expectedDifference)
    }

    @Test("Положительная дробная разница сохраняется точно")
    func preservesFractionalPositiveDifference() throws {
        let expectedAmount = try decimal("999.995")
        let expectedDifference = try decimal("0.005")
        let comparison = PaycheckComparison(
            expected: expectedGross(amount: expectedAmount),
            actualGross: try ActualGross(amount: Decimal(1_000))
        )

        #expect(comparison.difference == expectedDifference)
    }

    @Test("Сравнение сохраняет полный ожидаемый breakdown")
    func preservesCompleteExpectedBreakdown() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60)
        )
        let payRate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let shiftBreakdown = ShiftPayBreakdown(
            shift: shift,
            basePayBasis: .hourly,
            appliedPayRate: payRate,
            paidDuration: shift.paidDuration,
            basePay: Decimal(160)
        )
        let expected = ExpectedGrossBreakdown(
            period: .perShift(shiftID: shift.id),
            shiftBreakdowns: [shiftBreakdown],
            expectedGross: Decimal(160)
        )
        let comparison = PaycheckComparison(
            expected: expected,
            actualGross: try ActualGross(amount: Decimal(150))
        )

        #expect(comparison.expected == expected)
        #expect(comparison.expected.shiftBreakdowns == [shiftBreakdown])
    }

    private func expectedGross(amount: Decimal) -> ExpectedGrossBreakdown {
        ExpectedGrossBreakdown(
            period: .perShift(shiftID: UUID()),
            shiftBreakdowns: [],
            expectedGross: amount
        )
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        )
    }
}
