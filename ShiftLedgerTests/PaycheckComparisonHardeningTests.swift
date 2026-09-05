import Foundation
import Testing
@testable import ShiftLedger

struct PaycheckComparisonHardeningTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Нулевые expected и actual образуют полное нулевое сравнение")
    func supportsZeroExpectedAndActualGross() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let actualGross = try ActualGross(amount: .zero)

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 9),
            actualGross: actualGross,
            from: []
        )

        #expect(comparison.expected.expectedGross == .zero)
        #expect(comparison.expected.shiftBreakdowns.isEmpty)
        #expect(comparison.actualGross.amount == .zero)
        #expect(comparison.difference == .zero)
    }

    @Test("Очень малая положительная Decimal разница сохраняется точно")
    func preservesTinyPositiveDifference() throws {
        let rate = try PayRate(amount: decimal("100.000001"), effectiveFrom: nil)
        let job = try makeJob(basis: .fixedPerShift, payRates: [rate])
        let shift = try makeShift(month: 9, day: 10, hours: 1)

        let comparison = try job.paycheckComparison(
            for: .perShift(shiftID: shift.id),
            actualGross: try ActualGross(amount: decimal("100.000002")),
            from: [shift]
        )

        #expect(comparison.expected.expectedGross == (try decimal("100.000001")))
        #expect(comparison.difference == (try decimal("0.000001")))
    }

    @Test("Очень малая отрицательная Decimal разница сохраняется точно")
    func preservesTinyNegativeDifference() throws {
        let rate = try PayRate(amount: decimal("100.000002"), effectiveFrom: nil)
        let job = try makeJob(basis: .fixedPerShift, payRates: [rate])
        let shift = try makeShift(month: 9, day: 10, hours: 1)

        let comparison = try job.paycheckComparison(
            for: .perShift(shiftID: shift.id),
            actualGross: try ActualGross(amount: decimal("100.000001")),
            from: [shift]
        )

        #expect(comparison.expected.expectedGross == (try decimal("100.000002")))
        #expect(comparison.difference == (try decimal("-0.000001")))
    }

    @Test("Осенний DST сохраняет девять оплачиваемых часов в сравнении")
    func comparesFallBackElapsedPay() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try Shift(
            start: date(month: 10, day: 25, hour: 0),
            end: date(month: 10, day: 25, hour: 8)
        )

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 10),
            actualGross: try ActualGross(amount: decimal("179.50")),
            from: [shift]
        )
        let entry = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(entry.paidDuration == 9 * hour)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == Decimal(180))
        #expect(comparison.expected.expectedGross == Decimal(180))
        #expect(comparison.difference == (try decimal("-0.50")))
    }

    @Test("Весенний DST и перерыв сохраняют абсолютное время и точную сумму")
    func comparesSpringForwardShiftWithBreak() throws {
        let rate = try PayRate(amount: decimal("17.125"), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let start = try date(month: 3, day: 29, hour: 0)
        let end = try date(month: 3, day: 29, hour: 8)
        let breakStart = try date(month: 3, day: 29, hour: 1, minute: 30)
        let breakEnd = try date(month: 3, day: 29, hour: 3, minute: 30)
        let shift = try Shift(
            start: start,
            end: end,
            unpaidBreak: UnpaidBreak(start: breakStart, end: breakEnd)
        )
        let elapsedPaidDuration = end.timeIntervalSince(start)
            - breakEnd.timeIntervalSince(breakStart)
        let expectedPay = rate.amount * (Decimal(elapsedPaidDuration) / Decimal(3_600))

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 3),
            actualGross: try ActualGross(amount: decimal("102.749999")),
            from: [shift]
        )
        let entry = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(entry.paidDuration == elapsedPaidDuration)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == expectedPay)
        #expect(comparison.expected.expectedGross == expectedPay)
        #expect(expectedPay == (try decimal("102.75")))
        #expect(comparison.difference == (try decimal("-0.000001")))
    }

    @Test("Dated ставка применяется в точную effective date через comparison")
    func usesDatedRateOnExactEffectiveDate() throws {
        let initialRate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: Decimal(25),
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let shift = try makeShift(month: 9, day: 15, hours: 8)

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 9),
            actualGross: try ActualGross(amount: Decimal(195)),
            from: [shift]
        )
        let entry = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(entry.appliedPayRate == datedRate)
        #expect(entry.basePay == Decimal(200))
        #expect(comparison.expected.expectedGross == Decimal(200))
        #expect(comparison.difference == Decimal(-5))
    }

    @Test("Scheduled period исключает точную endExclusive дату")
    func excludesExactScheduledEndBoundary() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let septemberShift = try makeShift(month: 9, day: 30, hours: 8)
        let octoberShift = try makeShift(month: 10, day: 1, hours: 8)

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 9),
            actualGross: try ActualGross(amount: Decimal(150)),
            from: [octoberShift, septemberShift]
        )

        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [septemberShift])
        #expect(comparison.expected.expectedGross == Decimal(160))
        #expect(comparison.difference == Decimal(-10))
    }

    @Test("Ночная смена остаётся в периоде и на ставке локальной даты начала")
    func keepsOvernightShiftInStartDatePeriodAndRate() throws {
        let initialRate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let octoberRate = try PayRate(
            amount: Decimal(25),
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, octoberRate])
        let shift = try Shift(
            start: date(month: 9, day: 30, hour: 23),
            end: date(month: 10, day: 1, hour: 7)
        )

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 9),
            actualGross: try ActualGross(amount: Decimal(150)),
            from: [shift]
        )
        let entry = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(comparison.expected.shiftBreakdowns.count == 1)
        #expect(entry.shift == shift)
        #expect(entry.appliedPayRate == initialRate)
        #expect(entry.paidDuration == 8 * hour)
        #expect(entry.basePay == Decimal(160))
        #expect(comparison.expected.expectedGross == Decimal(160))
        #expect(comparison.difference == Decimal(-10))
    }

    @Test("Fixed-per-shift break сохраняет duration без уменьшения base pay")
    func preservesFixedPayWithUnpaidBreak() throws {
        let rate = try PayRate(amount: Decimal(175), effectiveFrom: nil)
        let job = try makeJob(basis: .fixedPerShift, payRates: [rate])
        let start = try date(month: 9, day: 10, hour: 8)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(2 * hour),
                end: start.addingTimeInterval(5 * hour)
            )
        )

        let comparison = try job.paycheckComparison(
            for: monthlyPeriod(month: 9),
            actualGross: try ActualGross(amount: Decimal(170)),
            from: [shift]
        )
        let entry = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(entry.basePayBasis == .fixedPerShift)
        #expect(entry.paidDuration == 5 * hour)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == Decimal(175))
        #expect(comparison.expected.expectedGross == Decimal(175))
        #expect(comparison.difference == Decimal(-5))
    }

    @Test("Разрешённый biweekly период сохраняет границы, membership и порядок")
    func comparesResolvedBiweeklyPeriod() throws {
        let anchor = try LocalDate(year: 2026, month: 9, day: 1)
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(
            cycle: .scheduled(.biweekly(anchorDate: anchor)),
            payRates: [rate]
        )
        let startBoundary = try makeShift(month: 9, day: 1, hours: 8)
        let reference = try makeShift(month: 9, day: 10, hours: 4)
        let endBoundary = try makeShift(month: 9, day: 15, hours: 8)
        let outside = try makeShift(month: 8, day: 31, hours: 8)
        let period = try job.payCalculationPeriod(for: reference)

        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: try ActualGross(amount: Decimal(230)),
            from: [endBoundary, reference, outside, startBoundary]
        )

        #expect(period == .scheduled(PayPeriod(
            start: anchor,
            endExclusive: try LocalDate(year: 2026, month: 9, day: 15)
        )))
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [startBoundary, reference])
        #expect(comparison.expected.shiftBreakdowns.map(\.basePay) == [Decimal(160), Decimal(80)])
        #expect(comparison.expected.expectedGross == Decimal(240))
        #expect(comparison.difference == Decimal(-10))
    }

    private func makeJob(
        basis: BasePayBasis = .hourly,
        cycle: PayCalculationCycle = .perShift,
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: basis,
            payCalculationCycle: cycle,
            payRates: payRates,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(
        month: Int,
        day: Int,
        hours: TimeInterval
    ) throws -> Shift {
        let start = try date(month: month, day: day, hour: 8)
        return try Shift(start: start, end: start.addingTimeInterval(hours * hour))
    }

    private func monthlyPeriod(month: Int) throws -> PayCalculationPeriod {
        .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: month, day: 1),
            endExclusive: try LocalDate(year: 2026, month: month + 1, day: 1)
        ))
    }

    private func date(
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        )
    }
}
