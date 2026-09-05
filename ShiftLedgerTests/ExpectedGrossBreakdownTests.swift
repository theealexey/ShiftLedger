import Foundation
import Testing
@testable import ShiftLedger

struct ExpectedGrossBreakdownTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Период без входящих смен сохраняется с пустым breakdown и нулевой суммой")
    func returnsEmptyBreakdownWhenNoShiftsQualify() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let period = try septemberPeriod()
        let outsideStart = try date(month: 8, day: 31)
        let outsideShift = try Shift(start: outsideStart, end: outsideStart.addingTimeInterval(hour))

        let result = try job.expectedGrossBreakdown(for: period, from: [outsideShift])

        #expect(result.period == period)
        #expect(result.shiftBreakdowns.isEmpty)
        #expect(result.expectedGross == .zero)
    }

    @Test("Breakdown содержит только смены внутри полуоткрытого периода")
    func includesOnlyPeriodMembers() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let beforeStart = try date(month: 8, day: 31)
        let endBoundary = try date(month: 10, day: 1, hour: 0)
        let before = try Shift(start: beforeStart, end: beforeStart.addingTimeInterval(hour))
        let after = try Shift(start: endBoundary, end: endBoundary.addingTimeInterval(hour))
        let first = try makeShift(day: 10, hours: 8)
        let second = try makeShift(day: 20, hours: 4)

        let result = try job.expectedGrossBreakdown(
            for: septemberPeriod(), from: [after, second, before, first]
        )

        #expect(result.shiftBreakdowns.map(\.shift) == [first, second])
        #expect(result.shiftBreakdowns.map(\.basePay) == [Decimal(160), Decimal(80)])
        #expect(result.expectedGross == Decimal(240))
    }

    @Test("Почасовой breakdown объясняет ставку и неоплачиваемый перерыв")
    func explainsHourlyShiftWithUnpaidBreak() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let start = try date(day: 10)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * hour),
                end: start.addingTimeInterval(4.5 * hour)
            )
        )

        let result = try job.expectedGrossBreakdown(for: septemberPeriod(), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.shift == shift)
        #expect(entry.basePayBasis == .hourly)
        #expect(entry.appliedPayRate == rate)
        #expect(entry.paidDuration == 7.5 * hour)
        #expect(entry.paidDuration == entry.shift.paidDuration)
        #expect(entry.basePay == Decimal(150))
        #expect(entry.basePay == (try job.basePay(for: entry.shift)))
        #expect(result.expectedGross == Decimal(150))
    }

    @Test("Каждая смена раскрывает точную историческую запись ставки")
    func exposesHistoricalRatesPerShift() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let first = try makeShift(day: 10)
        let second = try makeShift(day: 20)

        let result = try job.expectedGrossBreakdown(for: septemberPeriod(), from: [second, first])
        try #require(result.shiftBreakdowns.count == 2)

        #expect(result.shiftBreakdowns[0].shift == first)
        #expect(result.shiftBreakdowns[0].appliedPayRate == initialRate)
        #expect(result.shiftBreakdowns[0].basePay == Decimal(160))
        #expect(result.shiftBreakdowns[1].shift == second)
        #expect(result.shiftBreakdowns[1].appliedPayRate == datedRate)
        #expect(result.shiftBreakdowns[1].basePay == Decimal(200))
        #expect(result.expectedGross == Decimal(360))
    }

    @Test("Фиксированная оплата сохраняет реальную длительность без пропорционального уменьшения")
    func explainsFixedPerShiftPayWithBreak() throws {
        let rate = try PayRate(amount: 180, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .fixedPerShift, payRates: [rate])
        let start = try date(day: 10)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(3 * hour),
                end: start.addingTimeInterval(5 * hour)
            )
        )

        let result = try job.expectedGrossBreakdown(for: septemberPeriod(), from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(entry.shift == shift)
        #expect(entry.basePayBasis == .fixedPerShift)
        #expect(entry.appliedPayRate == rate)
        #expect(entry.paidDuration == 6 * hour)
        #expect(entry.paidDuration == shift.paidDuration)
        #expect(entry.basePay == Decimal(180))
        #expect(entry.basePay == (try job.basePay(for: shift)))
        #expect(result.expectedGross == Decimal(180))
    }

    @Test("Per-shift breakdown содержит только смену с выбранным ID")
    func explainsOnlyMatchingPerShiftID() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let first = try makeShift(day: 5, hours: 1)
        let target = try makeShift(day: 10, hours: 2)
        let third = try makeShift(day: 20, hours: 4)
        let period = PayCalculationPeriod.perShift(shiftID: target.id)

        let result = try job.expectedGrossBreakdown(for: period, from: [third, first, target])

        #expect(result.period == period)
        #expect(result.shiftBreakdowns.map(\.shift) == [target])
        #expect(result.expectedGross == Decimal(40))
        #expect(result.expectedGross == (try job.basePay(for: target)))
    }

    @Test("Ночная смена объясняется одной полной записью в периоде начала")
    func keepsOvernightShiftWhole() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shift = try Shift(
            start: date(month: 8, day: 31, hour: 23),
            end: date(day: 1, hour: 7)
        )
        let period = PayCalculationPeriod.scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 9, day: 1)
        ))

        let result = try job.expectedGrossBreakdown(for: period, from: [shift])
        try #require(result.shiftBreakdowns.count == 1)
        let entry = try #require(result.shiftBreakdowns.first)

        #expect(result.period == period)
        #expect(entry.shift == shift)
        #expect(entry.paidDuration == 8 * hour)
        #expect(entry.basePay == Decimal(160))
        #expect(result.expectedGross == Decimal(160))
    }

    @Test("Часовая зона Job определяет наличие записи breakdown")
    func composesTimeZoneMembership() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let stockholmJob = try makeJob(payRates: [rate])
        let newYorkJob = try makeJob(timeZoneIdentifier: "America/New_York", payRates: [rate])
        let start = try date(day: 1, hour: 0, minute: 30, timeZoneIdentifier: "UTC")
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let period = try septemberPeriod()

        let stockholm = try stockholmJob.expectedGrossBreakdown(for: period, from: [shift])
        let newYork = try newYorkJob.expectedGrossBreakdown(for: period, from: [shift])

        #expect(stockholm.shiftBreakdowns.map(\.shift) == [shift])
        #expect(stockholm.expectedGross == Decimal(20))
        #expect(newYork.shiftBreakdowns.isEmpty)
        #expect(newYork.expectedGross == .zero)
    }

    @Test("Дробная оплата каждой смены и итог сохраняются без округления")
    func preservesFractionalAmounts() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let amount = try #require(Decimal(string: "17.125", locale: locale))
        let expectedPay = try #require(Decimal(string: "25.6875", locale: locale))
        let expectedTotal = try #require(Decimal(string: "51.375", locale: locale))
        let rate = try PayRate(amount: amount, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let shifts = [try makeShift(day: 10, hours: 1.5), try makeShift(day: 11, hours: 1.5)]

        let result = try job.expectedGrossBreakdown(for: septemberPeriod(), from: shifts)

        #expect(result.shiftBreakdowns.map(\.basePay) == [expectedPay, expectedPay])
        #expect(result.expectedGross == expectedTotal)
    }

    @Test("Breakdown упорядочен по start, end и UUID независимо от входного порядка")
    func ordersByStartThenEndThenUUID() throws {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [rate])
        let firstID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000001"))
        let secondID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000002"))
        let thirdID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000003"))
        let fourthID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000004"))
        let fifthID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000005"))
        let start = try date(day: 10)
        let earliest = try Shift(
            id: fifthID, start: start.addingTimeInterval(-hour), end: start.addingTimeInterval(12 * hour)
        )
        let shorter = try Shift(id: fourthID, start: start, end: start.addingTimeInterval(hour))
        let lowerID = try Shift(id: secondID, start: start, end: start.addingTimeInterval(2 * hour))
        let higherID = try Shift(id: thirdID, start: start, end: start.addingTimeInterval(2 * hour))
        let latest = try Shift(
            id: firstID, start: start.addingTimeInterval(hour), end: start.addingTimeInterval(2 * hour)
        )
        let input = [latest, higherID, earliest, lowerID, shorter]
        let period = try septemberPeriod()

        let result = try job.expectedGrossBreakdown(for: period, from: input)
        let reversedResult = try job.expectedGrossBreakdown(for: period, from: Array(input.reversed()))

        #expect(result.shiftBreakdowns.map(\.shift) == [earliest, shorter, lowerID, higherID, latest])
        #expect(result == reversedResult)
        #expect(input == [latest, higherID, earliest, lowerID, shorter])
    }

    @Test("Legacy expectedGross совпадает с breakdown и суммой объяснённых выплат")
    func agreesWithLegacyTotalAndEntrySum() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let beforeStart = try date(month: 8, day: 31)
        let outside = try Shift(start: beforeStart, end: beforeStart.addingTimeInterval(hour))
        let first = try makeShift(day: 10, hours: 8)
        let second = try makeShift(day: 20, hours: 4)
        let input = [second, outside, first]
        let period = try septemberPeriod()

        let result = try job.expectedGrossBreakdown(for: period, from: input)
        let legacyTotal = try job.expectedGross(for: period, from: input)
        let entrySum = result.shiftBreakdowns.reduce(Decimal.zero) { $0 + $1.basePay }

        #expect(result.shiftBreakdowns.map(\.shift) == [first, second])
        #expect(result.expectedGross == Decimal(260))
        #expect(legacyTotal == result.expectedGross)
        #expect(result.expectedGross == entrySum)
        for entry in result.shiftBreakdowns {
            #expect(entry.paidDuration == entry.shift.paidDuration)
            #expect(entry.basePay == (try job.basePay(for: entry.shift)))
        }
    }

    private func makeJob(
        basePayBasis: BasePayBasis = .hourly,
        timeZoneIdentifier: String = "Europe/Stockholm",
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: basePayBasis,
            payCalculationCycle: .perShift,
            payRates: payRates,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(day: Int, hours: TimeInterval = 8) throws -> Shift {
        let start = try date(day: day)
        return try Shift(start: start, end: start.addingTimeInterval(hours * hour))
    }

    private func septemberPeriod() throws -> PayCalculationPeriod {
        .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        ))
    }

    private func date(
        month: Int = 9,
        day: Int,
        hour: Int = 8,
        minute: Int = 0,
        timeZoneIdentifier: String = "Europe/Stockholm"
    ) throws -> Date {
        let timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )))
    }
}
