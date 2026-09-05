import Foundation
import Testing
@testable import ShiftLedger

struct ShiftPeriodMembershipTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Per-shift период включает смену с совпадающим ID")
    func perShiftPeriodIncludesMatchingID() throws {
        let shiftID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        let job = try makeJob()
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            id: shiftID,
            start: start,
            end: start.addingTimeInterval(hour)
        )

        #expect(try job.contains(shift, in: .perShift(shiftID: shiftID)))
    }

    @Test("Per-shift период исключает смену с другим ID")
    func perShiftPeriodExcludesDifferentID() throws {
        let firstID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        let secondID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        let job = try makeJob()
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

        #expect(try job.contains(secondShift, in: .perShift(shiftID: firstShift.id)) == false)
    }

    @Test("Scheduled период включает дату строго внутри диапазона")
    func scheduledPeriodIncludesDateInsideRange() throws {
        let job = try makeJob()
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 9, day: 15, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(try job.contains(shift, in: .scheduled(septemberPeriod())))
    }

    @Test("Scheduled период включает точную start границу")
    func scheduledPeriodIncludesExactStartBoundary() throws {
        let job = try makeJob()
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 9, day: 1, hour: 0, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(try job.contains(shift, in: .scheduled(septemberPeriod())))
    }

    @Test("Scheduled период исключает точную endExclusive границу")
    func scheduledPeriodExcludesExactEndBoundary() throws {
        let job = try makeJob()
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 10, day: 1, hour: 0, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(try job.contains(shift, in: .scheduled(septemberPeriod())) == false)
    }

    @Test("Scheduled период исключает дату до начала диапазона")
    func scheduledPeriodExcludesDateBeforeRange() throws {
        let job = try makeJob()
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 31, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))

        #expect(try job.contains(shift, in: .scheduled(septemberPeriod())) == false)
    }

    @Test("Часовая зона Job определяет scheduled membership")
    func usesJobTimeZoneForScheduledMembership() throws {
        let stockholmJob = try makeJob(timeZoneIdentifier: "Europe/Stockholm")
        let newYorkJob = try makeJob(timeZoneIdentifier: "America/New_York")
        let utc = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(
            date(year: 2026, month: 9, day: 1, hour: 0, minute: 30, in: utc)
        )
        let shift = try Shift(start: start, end: start.addingTimeInterval(hour))
        let period = try septemberPeriod()

        #expect(try stockholmJob.contains(shift, in: .scheduled(period)))
        #expect(try newYorkJob.contains(shift, in: .scheduled(period)) == false)
    }

    @Test("Ночная смена относится к периоду только по дате начала")
    func overnightShiftUsesOnlyStartDate() throws {
        let job = try makeJob()
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
        let endLocalDate = try LocalDate(date: shift.end, in: stockholm)
        let septemberFirst = try LocalDate(year: 2026, month: 9, day: 1)

        #expect(endLocalDate == septemberFirst)
        #expect(try job.contains(shift, in: .scheduled(augustPeriod)))
    }

    private func makeJob(
        timeZoneIdentifier: String = "Europe/Stockholm"
    ) throws -> Job {
        let payRate = try PayRate(amount: 1, effectiveFrom: nil)

        return try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [payRate],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
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
