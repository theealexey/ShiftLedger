import Foundation
import Testing
@testable import ShiftLedger

struct PayPeriodNavigationTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Date-defined период отсутствует для per-shift Job")
    func dateDefinedPeriodIsNilForPerShiftJob() throws {
        let job = try makeJob(cycle: .perShift)

        #expect(
            try job.payCalculationPeriod(
                containing: Date(timeIntervalSinceReferenceDate: 100_000)
            ) == nil
        )
    }

    @Test("Date-defined недельный период разрешается от anchor")
    func resolvesWeeklyPeriodContainingDate() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(cycle: .scheduled(.weekly(anchorDate: anchor)))
        let date = try date(year: 2026, month: 8, day: 5, hour: 8, in: "Europe/Stockholm")

        #expect(try job.payCalculationPeriod(containing: date) == .scheduled(PayPeriod(
            start: anchor,
            endExclusive: try localDate(year: 2026, month: 8, day: 10)
        )))
    }

    @Test("Date-defined двухнедельный период разрешается от anchor")
    func resolvesBiweeklyPeriodContainingDate() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(cycle: .scheduled(.biweekly(anchorDate: anchor)))
        let date = try date(year: 2026, month: 8, day: 12, hour: 8, in: "Europe/Stockholm")

        #expect(try job.payCalculationPeriod(containing: date) == .scheduled(PayPeriod(
            start: anchor,
            endExclusive: try localDate(year: 2026, month: 8, day: 17)
        )))
    }

    @Test("Date-defined календарный месячный период использует локальный месяц")
    func resolvesCalendarMonthlyPeriodContainingDate() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let date = try date(year: 2026, month: 9, day: 15, hour: 8, in: "Europe/Stockholm")

        #expect(try job.payCalculationPeriod(containing: date) == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )))
    }

    @Test("Job timezone определяет Date-defined календарный период")
    func dateDefinedPeriodUsesJobTimeZone() throws {
        let stockholmJob = try makeJob(
            timeZoneIdentifier: "Europe/Stockholm",
            cycle: .scheduled(.calendarMonthly)
        )
        let newYorkJob = try makeJob(
            timeZoneIdentifier: "America/New_York",
            cycle: .scheduled(.calendarMonthly)
        )
        let absoluteDate = try date(year: 2026, month: 9, day: 1, hour: 0, minute: 30, in: "UTC")

        #expect(try stockholmJob.payCalculationPeriod(containing: absoluteDate) == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )))
        #expect(try newYorkJob.payCalculationPeriod(containing: absoluteDate) == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 1),
            endExclusive: try localDate(year: 2026, month: 9, day: 1)
        )))
    }

    @Test("Shift-based и Date-defined scheduled API разрешают одинаковый период")
    func existingShiftBasedResolutionRemainsConsistent() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let job = try makeJob(cycle: .scheduled(.weekly(anchorDate: anchor)))
        let start = try date(year: 2026, month: 8, day: 5, hour: 8, in: "Europe/Stockholm")
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(
            try job.payCalculationPeriod(for: shift)
                == job.payCalculationPeriod(containing: start)
        )
    }

    @Test("Недельная навигация возвращает предыдущий период")
    func resolvesPreviousWeeklyPeriod() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.weekly(anchorDate: anchor)
        let period = try schedule.period(containing: anchor)

        #expect(try schedule.period(before: period) == PayPeriod(
            start: try localDate(year: 2026, month: 7, day: 27),
            endExclusive: anchor
        ))
    }

    @Test("Недельная навигация возвращает следующий период")
    func resolvesNextWeeklyPeriod() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.weekly(anchorDate: anchor)
        let period = try schedule.period(containing: anchor)

        #expect(try schedule.period(after: period) == PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 10),
            endExclusive: try localDate(year: 2026, month: 8, day: 17)
        ))
    }

    @Test("Двухнедельная навигация возвращает предыдущий период")
    func resolvesPreviousBiweeklyPeriod() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)
        let period = try schedule.period(containing: anchor)

        #expect(try schedule.period(before: period) == PayPeriod(
            start: try localDate(year: 2026, month: 7, day: 20),
            endExclusive: anchor
        ))
    }

    @Test("Двухнедельная навигация возвращает следующий период")
    func resolvesNextBiweeklyPeriod() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)
        let period = try schedule.period(containing: anchor)

        #expect(try schedule.period(after: period) == PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 17),
            endExclusive: try localDate(year: 2026, month: 8, day: 31)
        ))
    }

    @Test("Навигация пересекает anchor симметрично в обоих направлениях")
    func navigatesAcrossAnchorInBothDirections() throws {
        let anchor = try localDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)
        let anchorPeriod = try schedule.period(containing: anchor)
        let previousPeriod = try schedule.period(before: anchorPeriod)
        let nextPeriod = try schedule.period(after: anchorPeriod)

        #expect(try schedule.period(after: previousPeriod) == anchorPeriod)
        #expect(try schedule.period(before: nextPeriod) == anchorPeriod)
    }

    @Test("Месячная навигация назад учитывает различную длину месяцев")
    func resolvesPreviousCalendarMonthWithDifferentLength() throws {
        let schedule = PayPeriodSchedule.calendarMonthly
        let march = try schedule.period(containing: localDate(year: 2024, month: 3, day: 15))

        #expect(try schedule.period(before: march) == PayPeriod(
            start: try localDate(year: 2024, month: 2, day: 1),
            endExclusive: try localDate(year: 2024, month: 3, day: 1)
        ))
    }

    @Test("Месячная навигация возвращает следующий календарный месяц")
    func resolvesNextCalendarMonth() throws {
        let schedule = PayPeriodSchedule.calendarMonthly
        let september = try schedule.period(containing: localDate(year: 2026, month: 9, day: 15))

        #expect(try schedule.period(after: september) == PayPeriod(
            start: try localDate(year: 2026, month: 10, day: 1),
            endExclusive: try localDate(year: 2026, month: 11, day: 1)
        ))
    }

    @Test("Месячная навигация пересекает границу года в обоих направлениях")
    func navigatesCalendarMonthAcrossYearBoundary() throws {
        let schedule = PayPeriodSchedule.calendarMonthly
        let december = try schedule.period(containing: localDate(year: 2026, month: 12, day: 15))
        let january = try schedule.period(containing: localDate(year: 2027, month: 1, day: 15))

        #expect(try schedule.period(after: december) == PayPeriod(
            start: try localDate(year: 2027, month: 1, day: 1),
            endExclusive: try localDate(year: 2027, month: 2, day: 1)
        ))
        #expect(try schedule.period(before: january) == PayPeriod(
            start: try localDate(year: 2026, month: 12, day: 1),
            endExclusive: try localDate(year: 2027, month: 1, day: 1)
        ))
    }

    private func makeJob(
        timeZoneIdentifier: String = "Europe/Stockholm",
        cycle: PayCalculationCycle
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: cycle,
            payRates: [try PayRate(amount: 1, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func localDate(year: Int, month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        in timeZoneIdentifier: String
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        return try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
