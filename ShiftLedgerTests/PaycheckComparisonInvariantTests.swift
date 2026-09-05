import Foundation
import Testing
@testable import ShiftLedger

struct PaycheckComparisonInvariantTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Сумма breakdown равна expected gross и сохраняет период")
    func preservesBreakdownSumAndPeriod() throws {
        let fixture = try scheduledFixture()
        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(340)),
            from: fixture.shifts
        )
        let breakdownTotal = comparison.expected.shiftBreakdowns.reduce(Decimal.zero) {
            $0 + $1.basePay
        }

        #expect(comparison.expected.period == fixture.period)
        #expect(breakdownTotal == comparison.expected.expectedGross)
    }

    @Test("Сравнение сохраняет canonical expected breakdown без изменений")
    func preservesCanonicalBreakdownIdentity() throws {
        let fixture = try scheduledFixture()
        let directBreakdown = try fixture.job.expectedGrossBreakdown(
            for: fixture.period,
            from: fixture.shifts
        )
        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(340)),
            from: fixture.shifts
        )

        #expect(comparison.expected == directBreakdown)
    }

    @Test("Legacy expected gross совпадает с суммой внутри сравнения")
    func preservesLegacyExpectedGrossConsistency() throws {
        let fixture = try scheduledFixture()
        let legacyExpected = try fixture.job.expectedGross(
            for: fixture.period,
            from: fixture.shifts
        )
        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(340)),
            from: fixture.shifts
        )

        #expect(comparison.expected.expectedGross == legacyExpected)
    }

    @Test("Изменение actual gross не меняет expected evidence")
    func changesOnlyDifferenceWhenActualGrossChanges() throws {
        let fixture = try scheduledFixture()
        let actualA = try ActualGross(amount: Decimal(300))
        let actualB = try ActualGross(amount: Decimal(425))
        let comparisonA = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: actualA,
            from: fixture.shifts
        )
        let comparisonB = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: actualB,
            from: fixture.shifts
        )

        #expect(comparisonA.expected == comparisonB.expected)
        #expect(comparisonB.difference - comparisonA.difference == actualB.amount - actualA.amount)
    }

    @Test("Порядок input не меняет сравнение и canonical breakdown order")
    func preservesDeterministicBreakdownOrder() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let lowerID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000001"))
        let higherID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000002"))
        let start = try date(day: 10)
        let earliest = try Shift(
            start: start.addingTimeInterval(-hour),
            end: start
        )
        let shorter = try Shift(
            start: start,
            end: start.addingTimeInterval(hour)
        )
        let lowerUUID = try Shift(
            id: lowerID,
            start: start,
            end: start.addingTimeInterval(2 * hour)
        )
        let higherUUID = try Shift(
            id: higherID,
            start: start,
            end: start.addingTimeInterval(2 * hour)
        )
        let period = try septemberPeriod()
        let actualGross = try ActualGross(amount: Decimal(120))

        let comparisonA = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: [earliest, shorter, lowerUUID, higherUUID]
        )
        let comparisonB = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: [higherUUID, earliest, lowerUUID, shorter]
        )

        #expect(comparisonA == comparisonB)
        #expect(
            comparisonA.expected.shiftBreakdowns.map(\.shift)
                == [earliest, shorter, lowerUUID, higherUUID]
        )
    }

    @Test("Повторённый Shift остаётся двумя расчётными входами")
    func preservesDuplicateShiftInputs() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try makeShift(day: 10, hours: 8)
        let actualGross = try ActualGross(amount: Decimal(300))
        let comparison = try job.paycheckComparison(
            for: .perShift(shiftID: shift.id),
            actualGross: actualGross,
            from: [shift, shift]
        )

        #expect(comparison.expected.shiftBreakdowns.count == 2)
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [shift, shift])
        #expect(comparison.expected.expectedGross == Decimal(320))
        #expect(comparison.difference == actualGross.amount - comparison.expected.expectedGross)
    }

    @Test("Период без qualifying Shifts сохраняет нулевые expected invariants")
    func preservesEmptyPeriodInvariants() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let period = try septemberPeriod()
        let outside = try makeShift(month: 8, day: 31, hours: 8)
        let actualGross = try ActualGross(amount: Decimal(250))
        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: [outside]
        )
        let breakdownTotal = comparison.expected.shiftBreakdowns.reduce(Decimal.zero) {
            $0 + $1.basePay
        }

        #expect(comparison.expected.period == period)
        #expect(comparison.expected.shiftBreakdowns.isEmpty)
        #expect(comparison.expected.expectedGross == .zero)
        #expect(breakdownTotal == .zero)
        #expect(comparison.difference == comparison.actualGross.amount)
    }

    @Test("Per-shift comparison содержит только Shift с разрешённым ID")
    func preservesPerShiftMembershipInvariant() throws {
        let rate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let job = try makeJob(payCalculationCycle: .perShift, payRates: [rate])
        let otherA = try makeShift(day: 9, hours: 8)
        let target = try makeShift(day: 10, hours: 2)
        let otherB = try makeShift(day: 11, hours: 4)
        let period = try job.payCalculationPeriod(for: target)
        let actualGross = try ActualGross(amount: Decimal(35))
        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: actualGross,
            from: [otherB, target, otherA]
        )
        let targetBreakdown = try #require(comparison.expected.shiftBreakdowns.first)

        #expect(period == .perShift(shiftID: target.id))
        #expect(comparison.expected.shiftBreakdowns.map(\.shift) == [target])
        #expect(comparison.expected.expectedGross == targetBreakdown.basePay)
        #expect(comparison.difference == actualGross.amount - targetBreakdown.basePay)
    }

    @Test("Comparison сохраняет полное evidence ставок, времени и base pay")
    func preservesExplainabilityEvidence() throws {
        let fixture = try scheduledFixture()
        let comparison = try fixture.job.paycheckComparison(
            for: fixture.period,
            actualGross: try ActualGross(amount: Decimal(340)),
            from: fixture.shifts
        )
        try #require(comparison.expected.shiftBreakdowns.count == 2)
        let first = comparison.expected.shiftBreakdowns[0]
        let second = comparison.expected.shiftBreakdowns[1]

        #expect(first.shift == fixture.first)
        #expect(first.basePayBasis == .hourly)
        #expect(first.appliedPayRate == fixture.initialRate)
        #expect(first.paidDuration == fixture.first.paidDuration)
        #expect(first.basePay == Decimal(150))
        #expect(second.shift == fixture.second)
        #expect(second.basePayBasis == .hourly)
        #expect(second.appliedPayRate == fixture.datedRate)
        #expect(second.paidDuration == fixture.second.paidDuration)
        #expect(second.basePay == Decimal(200))
    }

    @Test("Дробные Decimal значения остаются точными во всей цепочке")
    func preservesFractionalExactnessAcrossChain() throws {
        let rate = try PayRate(amount: decimal("17.125"), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try makeShift(day: 10, hours: 1.5)
        let comparison = try job.paycheckComparison(
            for: .perShift(shiftID: shift.id),
            actualGross: try ActualGross(amount: decimal("25.68")),
            from: [shift]
        )
        let breakdownTotal = comparison.expected.shiftBreakdowns.reduce(Decimal.zero) {
            $0 + $1.basePay
        }

        #expect(breakdownTotal == (try decimal("25.6875")))
        #expect(comparison.expected.expectedGross == (try decimal("25.6875")))
        #expect(comparison.difference == (try decimal("-0.0075")))
    }

    private func scheduledFixture() throws -> (
        job: Job,
        period: PayCalculationPeriod,
        shifts: [Shift],
        first: Shift,
        second: Shift,
        initialRate: PayRate,
        datedRate: PayRate
    ) {
        let initialRate = try PayRate(amount: Decimal(20), effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: Decimal(25),
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let firstStart = try date(day: 10)
        let first = try Shift(
            start: firstStart,
            end: firstStart.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: firstStart.addingTimeInterval(4 * hour),
                end: firstStart.addingTimeInterval(4.5 * hour)
            )
        )
        let second = try makeShift(day: 20, hours: 8)
        let outside = try makeShift(month: 8, day: 31, hours: 8)

        return (
            job,
            try septemberPeriod(),
            [second, outside, first],
            first,
            second,
            initialRate,
            datedRate
        )
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
        month: Int = 9,
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

    private func date(month: Int = 9, day: Int) throws -> Date {
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
