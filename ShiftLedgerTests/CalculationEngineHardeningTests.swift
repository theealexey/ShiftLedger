import Foundation
import Testing
@testable import ShiftLedger

struct CalculationEngineHardeningTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Повторённая входная смена учитывается дважды без дедупликации")
    func preservesDuplicateShiftInputs() throws {
        let job = try makeJob()
        let shift = try makeShift(day: 10)
        let period = try monthlyPeriod(month: 9)
        let input = [shift, shift]

        let result = try job.expectedGrossBreakdown(for: period, from: input)

        #expect(result.shiftBreakdowns.map(\.shift) == [shift, shift])
        #expect(result.shiftBreakdowns.map(\.basePay) == [Decimal(160), Decimal(160)])
        #expect(result.expectedGross == Decimal(320))
        #expect(try job.expectedGross(for: period, from: input) == Decimal(320))
    }

    @Test("Непустой input без совпадающего per-shift ID даёт пустой breakdown и ноль")
    func returnsZeroForUnmatchedPerShiftPeriod() throws {
        let job = try makeJob()
        let shiftID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000001"))
        let absentID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000002"))
        let start = try date(day: 10)
        let shift = try Shift(id: shiftID, start: start, end: start.addingTimeInterval(8 * hour))
        let period = PayCalculationPeriod.perShift(shiftID: absentID)

        let result = try job.expectedGrossBreakdown(for: period, from: [shift])

        #expect(result.period == period)
        #expect(result.shiftBreakdowns.isEmpty)
        #expect(result.expectedGross == .zero)
        #expect(try job.expectedGross(for: period, from: [shift]) == .zero)
    }

    @Test("Точное начало периода включает смену и ставку с той же effective date")
    func composesInclusivePeriodAndRateBoundaries() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let start = try date(day: 1, hour: 0)
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))
        let period = try monthlyPeriod(month: 9)

        let result = try job.expectedGrossBreakdown(for: period, from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(try job.contains(shift, in: period))
        #expect(try job.applicablePayRate(for: shift) == datedRate)
        #expect(entry.shift == shift)
        #expect(entry.appliedPayRate == datedRate)
        #expect(entry.basePay == Decimal(200))
        #expect(result.expectedGross == Decimal(200))
    }

    @Test("Осенний DST проходит через breakdown как девять оплачиваемых часов")
    func explainsFallBackElapsedPay() throws {
        let job = try makeJob()
        let shift = try Shift(
            start: date(month: 10, day: 25, hour: 0),
            end: date(month: 10, day: 25, hour: 8)
        )

        let result = try job.expectedGrossBreakdown(for: monthlyPeriod(month: 10), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.shift == shift)
        #expect(entry.paidDuration == 9 * hour)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == Decimal(180))
        #expect(result.expectedGross == Decimal(180))
    }

    @Test("Весенний DST и перерыв через переход сохраняют elapsed-семантику в полной оплате")
    func composesSpringForwardBreakThroughBreakdown() throws {
        let amount = try decimal("17.125")
        let rate = try PayRate(amount: amount, effectiveFrom: nil)
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
        let elapsedPaidDuration = end.timeIntervalSince(start) - breakEnd.timeIntervalSince(breakStart)
        let expectedPay = amount * (Decimal(elapsedPaidDuration) / Decimal(3_600))

        let result = try job.expectedGrossBreakdown(for: monthlyPeriod(month: 3), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.appliedPayRate == rate)
        #expect(entry.paidDuration == elapsedPaidDuration)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == expectedPay)
        #expect(entry.basePay == (try job.basePay(for: shift)))
        #expect(result.expectedGross == entry.basePay)
    }

    @Test("Разрешённый biweekly период напрямую задаёт membership и порядок breakdown")
    func resolvesScheduledPeriodThroughBreakdown() throws {
        let anchor = try LocalDate(year: 2026, month: 9, day: 14)
        let job = try makeJob(cycle: .scheduled(.biweekly(anchorDate: anchor)))
        let reference = try makeShift(day: 10)
        let earlier = try makeShift(day: 2, hours: 4)
        let outside = try makeShift(day: 14)

        let period = try job.payCalculationPeriod(for: reference)
        let result = try job.expectedGrossBreakdown(for: period, from: [outside, reference, earlier])

        #expect(period == .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 31),
            endExclusive: anchor
        )))
        #expect(result.period == period)
        #expect(result.shiftBreakdowns.map(\.shift) == [earlier, reference])
        #expect(result.shiftBreakdowns.map(\.basePay) == [Decimal(80), Decimal(160)])
        #expect(result.expectedGross == Decimal(240))
    }

    @Test("Разрешённый per-shift период передаёт точную смену в breakdown")
    func resolvesPerShiftPeriodThroughBreakdown() throws {
        let job = try makeJob(cycle: .perShift)
        let first = try makeShift(day: 5, hours: 1)
        let target = try makeShift(day: 10, hours: 2)
        let third = try makeShift(day: 20, hours: 4)

        let period = try job.payCalculationPeriod(for: target)
        let result = try job.expectedGrossBreakdown(for: period, from: [third, first, target])

        #expect(period == .perShift(shiftID: target.id))
        #expect(result.period == period)
        #expect(result.shiftBreakdowns.map(\.shift) == [target])
        #expect(result.expectedGross == Decimal(40))
    }

    @Test("Legacy и breakdown согласованы при истории ставок, перерыве и исключённой смене")
    func keepsLegacyTotalConsistentWithHistoricalRatesAndBreak() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let start = try date(day: 10)
        let first = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * hour),
                end: start.addingTimeInterval(4.5 * hour)
            )
        )
        let second = try makeShift(day: 20)
        let outsideStart = try date(month: 8, day: 31)
        let outside = try Shift(start: outsideStart, end: outsideStart.addingTimeInterval(8 * hour))
        let input = [second, outside, first]
        let period = try monthlyPeriod(month: 9)

        let result = try job.expectedGrossBreakdown(for: period, from: input)
        let legacyTotal = try job.expectedGross(for: period, from: input)
        let entrySum = result.shiftBreakdowns.reduce(Decimal.zero) { $0 + $1.basePay }

        #expect(result.shiftBreakdowns.map(\.shift) == [first, second])
        #expect(result.shiftBreakdowns.map(\.appliedPayRate) == [initialRate, datedRate])
        #expect(result.shiftBreakdowns.map(\.basePay) == [Decimal(150), Decimal(200)])
        #expect(result.expectedGross == Decimal(350))
        #expect(legacyTotal == result.expectedGross)
        #expect(result.expectedGross == entrySum)
    }

    @Test("Fixed pay при осеннем DST не зависит от девяти часов в breakdown")
    func preservesFixedPayAcrossFallBack() throws {
        let rate = try PayRate(amount: 175, effectiveFrom: nil)
        let job = try makeJob(basis: .fixedPerShift, payRates: [rate])
        let shift = try Shift(
            start: date(month: 10, day: 25, hour: 0),
            end: date(month: 10, day: 25, hour: 8)
        )

        let result = try job.expectedGrossBreakdown(for: monthlyPeriod(month: 10), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.basePayBasis == .fixedPerShift)
        #expect(entry.appliedPayRate == rate)
        #expect(entry.paidDuration == 9 * hour)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == rate.amount)
        #expect(result.expectedGross == Decimal(175))
    }

    @Test("Дробные секунды доходят до дробной денежной суммы без округления")
    func preservesFractionalSecondsThroughGross() throws {
        let rate = try PayRate(amount: decimal("17.125"), effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let start = try date(day: 10).addingTimeInterval(0.125)
        let end = start.addingTimeInterval(hour + 0.5625)
        let shift = try Shift(start: start, end: end)
        let expectedPay = try decimal("17.12767578125")

        let result = try job.expectedGrossBreakdown(for: monthlyPeriod(month: 9), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.paidDuration == end.timeIntervalSince(start))
        #expect(entry.paidDuration == hour + 0.5625)
        #expect(entry.basePay == expectedPay)
        #expect(result.expectedGross == expectedPay)
    }

    private func makeJob(
        basis: BasePayBasis = .hourly,
        cycle: PayCalculationCycle = .perShift,
        payRates: [PayRate]? = nil
    ) throws -> Job {
        let rates = try payRates ?? [PayRate(amount: 20, effectiveFrom: nil)]
        return try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: basis,
            payCalculationCycle: cycle,
            payRates: rates,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(day: Int, hours: TimeInterval = 8) throws -> Shift {
        let start = try date(day: day)
        return try Shift(start: start, end: start.addingTimeInterval(hours * hour))
    }

    private func monthlyPeriod(month: Int) throws -> PayCalculationPeriod {
        .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: month, day: 1),
            endExclusive: try LocalDate(year: 2026, month: month + 1, day: 1)
        ))
    }

    private func date(month: Int = 9, day: Int, hour: Int = 8, minute: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        return try #require(calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}
