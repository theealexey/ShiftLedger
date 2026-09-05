import Foundation
import Testing
@testable import ShiftLedger

struct ExpectedGrossTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Пустой scheduled период возвращает нулевой expected gross")
    func returnsZeroForEmptyScheduledPeriod() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: []) == .zero)
    }

    @Test("Scheduled период суммирует только входящие смены")
    func includesOnlyScheduledPeriodMembers() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let outsideBeforeStart = try #require(
            date(year: 2026, month: 8, day: 31, hour: 8, in: stockholm)
        )
        let firstMemberStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let secondMemberStart = try #require(
            date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm)
        )
        let outsideEndStart = try #require(
            date(year: 2026, month: 10, day: 1, hour: 8, in: stockholm)
        )
        let shifts = [
            try Shift(start: outsideBeforeStart, end: outsideBeforeStart.addingTimeInterval(hour)),
            try Shift(start: firstMemberStart, end: firstMemberStart.addingTimeInterval(8 * hour)),
            try Shift(start: secondMemberStart, end: secondMemberStart.addingTimeInterval(4 * hour)),
            try Shift(start: outsideEndStart, end: outsideEndStart.addingTimeInterval(hour))
        ]

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: shifts) == Decimal(240))
    }

    @Test("Несколько почасовых смен суммируют неоплачиваемые перерывы")
    func aggregatesHourlyShiftsWithUnpaidBreak() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let secondStart = try #require(
            date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm)
        )
        let shifts = [
            try Shift(start: firstStart, end: firstStart.addingTimeInterval(8 * hour)),
            try Shift(
                start: secondStart,
                end: secondStart.addingTimeInterval(8 * hour),
                unpaidBreak: UnpaidBreak(
                    start: secondStart.addingTimeInterval(4 * hour),
                    end: secondStart.addingTimeInterval(4.5 * hour)
                )
            )
        ]

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: shifts) == Decimal(310))
    }

    @Test("Исторические ставки суммируются внутри одного периода")
    func aggregatesHistoricalRatesWithinPeriod() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 15)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let secondStart = try #require(
            date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm)
        )
        let shifts = [
            try Shift(start: firstStart, end: firstStart.addingTimeInterval(8 * hour)),
            try Shift(start: secondStart, end: secondStart.addingTimeInterval(8 * hour))
        ]

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: shifts) == Decimal(360))
    }

    @Test("Фиксированная ставка суммируется один раз на смену")
    func aggregatesFixedPerShiftRates() throws {
        let payRate = try PayRate(amount: 180, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .fixedPerShift, payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let secondStart = try #require(
            date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm)
        )
        let shifts = [
            try Shift(
                start: firstStart,
                end: firstStart.addingTimeInterval(2 * hour),
                unpaidBreak: UnpaidBreak(
                    start: firstStart.addingTimeInterval(0.5 * hour),
                    end: firstStart.addingTimeInterval(hour)
                )
            ),
            try Shift(start: secondStart, end: secondStart.addingTimeInterval(12 * hour))
        ]

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: shifts) == Decimal(360))
    }

    @Test("Per-shift период суммирует только смену с точным ID")
    func selectsOnlyMatchingPerShiftID() throws {
        let firstID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000001"))
        let secondID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000002"))
        let thirdID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000003"))
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let firstShift = try Shift(
            id: firstID,
            start: start,
            end: start.addingTimeInterval(hour)
        )
        let secondShift = try Shift(
            id: secondID,
            start: start.addingTimeInterval(2 * hour),
            end: start.addingTimeInterval(4 * hour)
        )
        let thirdShift = try Shift(
            id: thirdID,
            start: start.addingTimeInterval(5 * hour),
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(
            try job.expectedGross(
                for: .perShift(shiftID: secondShift.id),
                from: [firstShift, secondShift, thirdShift]
            ) == Decimal(40)
        )
    }

    @Test("Ночная смена полностью входит в период даты начала")
    func includesOvernightShiftInStartPeriod() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 31, hour: 23, in: stockholm)
        )
        let end = try #require(
            date(year: 2026, month: 9, day: 1, hour: 7, in: stockholm)
        )
        let shift = try Shift(start: start, end: end)

        #expect(try job.expectedGross(for: .scheduled(augustPeriod()), from: [shift]) == Decimal(160))
    }

    @Test("Граница часовой зоны меняет membership коллекции")
    func usesJobTimeZoneForCollectionMembership() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let stockholmJob = try makeJob(
            timeZoneIdentifier: "Europe/Stockholm",
            payRates: [payRate]
        )
        let newYorkJob = try makeJob(
            timeZoneIdentifier: "America/New_York",
            payRates: [payRate]
        )
        let utc = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(
            date(year: 2026, month: 9, day: 1, hour: 0, minute: 30, in: utc)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(try stockholmJob.expectedGross(for: .scheduled(septemberPeriod()), from: [shift]) == Decimal(20))
        #expect(try newYorkJob.expectedGross(for: .scheduled(septemberPeriod()), from: [shift]) == .zero)
    }

    @Test("Дробная сумма expected gross не округляется")
    func preservesFractionalExpectedGross() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let rateAmount = try #require(Decimal(string: "17.125", locale: locale))
        let expectedGross = try #require(Decimal(string: "51.375", locale: locale))
        let payRate = try PayRate(amount: rateAmount, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let secondStart = try #require(
            date(year: 2026, month: 9, day: 11, hour: 8, in: stockholm)
        )
        let shifts = [
            try Shift(start: firstStart, end: firstStart.addingTimeInterval(1.5 * hour)),
            try Shift(start: secondStart, end: secondStart.addingTimeInterval(1.5 * hour))
        ]

        #expect(try job.expectedGross(for: .scheduled(septemberPeriod()), from: shifts) == expectedGross)
    }

    @Test("Порядок входной коллекции не меняет expected gross")
    func producesSameGrossForDifferentInputOrder() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstStart = try #require(
            date(year: 2026, month: 9, day: 5, hour: 8, in: stockholm)
        )
        let secondStart = try #require(
            date(year: 2026, month: 9, day: 10, hour: 8, in: stockholm)
        )
        let thirdStart = try #require(
            date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm)
        )
        let firstShift = try Shift(start: firstStart, end: firstStart.addingTimeInterval(hour))
        let secondShift = try Shift(start: secondStart, end: secondStart.addingTimeInterval(2 * hour))
        let thirdShift = try Shift(start: thirdStart, end: thirdStart.addingTimeInterval(4 * hour))
        let orderedGross = try job.expectedGross(
            for: .scheduled(septemberPeriod()),
            from: [firstShift, secondShift, thirdShift]
        )
        let reorderedGross = try job.expectedGross(
            for: .scheduled(septemberPeriod()),
            from: [thirdShift, firstShift, secondShift]
        )

        #expect(orderedGross == Decimal(140))
        #expect(reorderedGross == orderedGross)
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

    private func augustPeriod() throws -> PayPeriod {
        PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 9, day: 1)
        )
    }

    private func septemberPeriod() throws -> PayPeriod {
        PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        in timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )
    }
}
