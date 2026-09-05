import Foundation
import Testing
@testable import ShiftLedger

struct PaycheckComparisonCalculationTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Точное совпадение возвращает полный breakdown и нулевую разницу")
    func calculatesExactMatch() throws {
        let fixture = try standardFixture()
        let actualGross = try ActualGross(amount: Decimal(160))

        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: actualGross,
            from: [fixture.shift]
        )
        let canonicalBreakdown = try fixture.job.expectedGrossBreakdown(
            for: fixture.period,
            from: [fixture.shift]
        )

        #expect(comparison.expected == canonicalBreakdown)
        #expect(comparison.expected.expectedGross == Decimal(160))
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [fixture.shift])
        #expect(comparison.actualGross == actualGross)
        #expect(comparison.difference == .zero)
    }

    @Test("Фактическая сумма ниже ожидаемой сохраняет отрицательный знак")
    func calculatesLowerActualGross() throws {
        let fixture = try standardFixture()

        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(150)),
            from: [fixture.shift]
        )

        #expect(comparison.expected.expectedGross == Decimal(160))
        #expect(comparison.difference == Decimal(-10))
    }

    @Test("Фактическая сумма выше ожидаемой сохраняет положительный знак")
    func calculatesHigherActualGross() throws {
        let fixture = try standardFixture()

        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(175)),
            from: [fixture.shift]
        )

        #expect(comparison.expected.expectedGross == Decimal(160))
        #expect(comparison.difference == Decimal(15))
    }

    @Test("Нулевой actual gross проходит через Job API без изменения")
    func comparesZeroActualGross() throws {
        let fixture = try standardFixture()

        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: .zero),
            from: [fixture.shift]
        )

        #expect(comparison.actualGross.amount == .zero)
        #expect(comparison.difference == Decimal(-160))
    }

    @Test("Пустой период сравнивается как нулевой expected gross")
    func comparesEmptyPeriod() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let period = try septemberPeriod()
        let actualGross = try ActualGross(amount: Decimal(250))

        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: []
        )

        #expect(comparison.expected.period == period)
        #expect(comparison.expected.shiftBreakdowns.isEmpty)
        #expect(comparison.expected.expectedGross == .zero)
        #expect(comparison.actualGross == actualGross)
        #expect(comparison.difference == Decimal(250))
    }

    @Test("Сравнение сохраняет исторические ставки, перерыв и порядок breakdown")
    func preservesCompleteCalculationEvidence() throws {
        let initialRate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: Decimal(25),
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let firstStart = try date(month: 9, day: 10)
        let first = try Shift(
            start: firstStart,
            end: firstStart.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: firstStart.addingTimeInterval(4 * hour),
                end: firstStart.addingTimeInterval(4.5 * hour)
            )
        )
        let second = try makeShift(month: 9, day: 20, hours: 8)
        let outside = try makeShift(month: 8, day: 31, hours: 8)
        let period = try septemberPeriod()
        let actualGross = try ActualGross(amount: Decimal(340))

        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: [second, outside, first]
        )

        #expect(comparison.expected.period == period)
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [first, second])
        #expect(comparison.expected.shiftBreakdowns.map(\.appliedPayRate) == [initialRate, datedRate])
        #expect(comparison.expected.shiftBreakdowns.map(\.paidDuration) == [7.5 * hour, 8 * hour])
        #expect(comparison.expected.shiftBreakdowns.map(\.basePay) == [Decimal(150), Decimal(200)])
        #expect(comparison.expected.expectedGross == Decimal(350))
        #expect(comparison.actualGross == actualGross)
        #expect(comparison.difference == Decimal(-10))
    }

    @Test("Дробная Decimal разница не округляется")
    func preservesFractionalDifference() throws {
        let rate = try PayRate(amount: decimal("17.125"), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try makeShift(month: 9, day: 10, hours: 1.5)
        let period = PayCalculationPeriod.perShift(shiftID: shift.id)

        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: try ActualGross(amount: decimal("25.68")),
            from: [shift]
        )

        #expect(comparison.expected.expectedGross == (try decimal("25.6875")))
        #expect(comparison.difference == (try decimal("-0.0075")))
    }

    @Test("Разрешённый per-shift период включает только целевую смену")
    func composesResolvedPerShiftPeriod() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payCalculationCycle: .perShift, payRates: [rate])
        let target = try makeShift(month: 9, day: 10, hours: 2)
        let other = try makeShift(month: 9, day: 11, hours: 8)
        let period = try job.payCalculationPeriod(for: target)

        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: try ActualGross(amount: Decimal(35)),
            from: [other, target]
        )

        #expect(period == .perShift(shiftID: target.id))
        #expect(comparison.expected.period == period)
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [target])
        #expect(comparison.expected.expectedGross == Decimal(40))
        #expect(comparison.difference == Decimal(-5))
    }

    private func standardFixture() throws -> (
        job: Job,
        period: PayCalculationPeriod,
        shift: Shift
    ) {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try makeShift(month: 9, day: 10, hours: 8)
        return (job, .perShift(shiftID: shift.id), shift)
    }

    private func makeJob(
        payCalculationCycle: PayCalculationCycle = .perShift,
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: payCalculationCycle,
            payRates: payRates,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(
        month: Int,
        day: Int,
        hours: TimeInterval
    ) throws -> Shift {
        let start = try date(month: month, day: day)
        return try Shift(start: start, end: start.addingTimeInterval(hours * hour))
    }

    private func septemberPeriod() throws -> PayCalculationPeriod {
        .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        ))
    }

    private func date(month: Int, day: Int) throws -> Date {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: month,
            day: day,
            hour: 8
        )))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        )
    }
}
