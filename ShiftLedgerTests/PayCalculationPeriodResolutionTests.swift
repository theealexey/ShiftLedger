import Foundation
import Testing
@testable import ShiftLedger

struct PayCalculationPeriodResolutionTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Per-shift период содержит точный идентификатор смены")
    func perShiftPeriodContainsExactShiftID() throws {
        let shiftID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001"))
        let job = try makeJob(payCalculationCycle: .perShift)
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            id: shiftID,
            start: start,
            end: start.addingTimeInterval(hour)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .perShift(shiftID: shiftID))
    }

    @Test("Разные смены создают разные per-shift периоды")
    func differentShiftsProduceDifferentPerShiftPeriods() throws {
        let firstID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001"))
        let secondID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000002"))
        let job = try makeJob(payCalculationCycle: .perShift)
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let firstShift = try Shift(
            id: firstID,
            start: start,
            end: start.addingTimeInterval(hour)
        )
        let secondShift = try Shift(
            id: secondID,
            start: start,
            end: start.addingTimeInterval(hour)
        )

        #expect(
            try job.payCalculationPeriod(for: firstShift)
                != job.payCalculationPeriod(for: secondShift)
        )
    }

    @Test("Недельный schedule разрешается через дату начала смены")
    func resolvesWeeklySchedule() throws {
        let anchor = try LocalDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(
            payCalculationCycle: .scheduled(.weekly(anchorDate: anchor))
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 5, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let expectedPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 3),
            endExclusive: try LocalDate(year: 2026, month: 8, day: 10)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .scheduled(expectedPeriod))
    }

    @Test("Двухнедельный schedule разрешается от anchor")
    func resolvesBiweeklySchedule() throws {
        let anchor = try LocalDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(
            payCalculationCycle: .scheduled(.biweekly(anchorDate: anchor))
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 12, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let expectedPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 3),
            endExclusive: try LocalDate(year: 2026, month: 8, day: 17)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .scheduled(expectedPeriod))
    }

    @Test("Календарный месячный schedule использует локальный месяц")
    func resolvesCalendarMonthlySchedule() throws {
        let job = try makeJob(
            payCalculationCycle: .scheduled(.calendarMonthly)
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 9, day: 15, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let expectedPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .scheduled(expectedPeriod))
    }

    @Test("Часовая зона Job определяет месячный период")
    func usesJobTimeZoneForScheduledPeriod() throws {
        let stockholmJob = try makeJob(
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .scheduled(.calendarMonthly)
        )
        let newYorkJob = try makeJob(
            timeZoneIdentifier: "America/New_York",
            payCalculationCycle: .scheduled(.calendarMonthly)
        )
        let utc = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(
            date(year: 2026, month: 9, day: 1, hour: 0, minute: 30, in: utc)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let septemberPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let augustPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 9, day: 1)
        )

        #expect(
            try stockholmJob.payCalculationPeriod(for: shift)
                == .scheduled(septemberPeriod)
        )
        #expect(
            try newYorkJob.payCalculationPeriod(for: shift)
                == .scheduled(augustPeriod)
        )
    }

    @Test("Ночная смена целиком относится к периоду даты начала")
    func usesOnlyOvernightShiftStartDate() throws {
        let job = try makeJob(
            payCalculationCycle: .scheduled(.calendarMonthly)
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 31, hour: 23, in: stockholm)
        )
        let end = try #require(
            date(year: 2026, month: 9, day: 1, hour: 7, in: stockholm)
        )
        let shift = try Shift(start: start, end: end)
        let augustPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 9, day: 1)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .scheduled(augustPeriod))
    }

    @Test("Точная endExclusive граница начинает следующий период")
    func advancesAtExactWeeklyBoundary() throws {
        let anchor = try LocalDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(
            payCalculationCycle: .scheduled(.weekly(anchorDate: anchor))
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 10, hour: 0, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let expectedPeriod = PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 10),
            endExclusive: try LocalDate(year: 2026, month: 8, day: 17)
        )

        #expect(try job.payCalculationPeriod(for: shift) == .scheduled(expectedPeriod))
    }

    private func makeJob(
        timeZoneIdentifier: String = "Europe/Stockholm",
        payCalculationCycle: PayCalculationCycle
    ) throws -> Job {
        let payRate = try PayRate(amount: 1, effectiveFrom: nil)

        return try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: payCalculationCycle,
            payRates: [payRate],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
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
