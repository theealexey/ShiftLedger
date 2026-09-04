import Foundation
import Testing
@testable import ShiftLedger

struct ApplicablePayRateTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Initial ставка применяется до первой dated ставки")
    func usesInitialRateBeforeFirstDatedRate() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 8, day: 31, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try job.applicablePayRate(for: shift) == initialRate)
    }

    @Test("Dated ставка применяется в точную effective date")
    func usesDatedRateOnItsEffectiveDate() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 9, day: 1, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try job.applicablePayRate(for: shift) == datedRate)
    }

    @Test("Последняя применимая dated ставка побеждает")
    func usesLatestApplicableDatedRate() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 140,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, septemberRate, octoberRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 9, day: 20, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try job.applicablePayRate(for: shift) == septemberRate)
    }

    @Test("Последняя dated ставка применяется после всех границ")
    func usesLatestRateAfterAllEffectiveDates() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 140,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, septemberRate, octoberRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 10, day: 15, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try job.applicablePayRate(for: shift) == octoberRate)
    }

    @Test("Будущая dated ставка не применяется")
    func excludesFutureDatedRate() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 140,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, septemberRate, octoberRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 9, day: 30, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try job.applicablePayRate(for: shift) == septemberRate)
    }

    @Test("Часовая зона Job определяет local start date")
    func usesJobTimeZoneInsteadOfDeviceTimeZone() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let stockholmJob = try makeJob(
            timeZoneIdentifier: "Europe/Stockholm",
            payRates: [initialRate, datedRate]
        )
        let newYorkJob = try makeJob(
            timeZoneIdentifier: "America/New_York",
            payRates: [initialRate, datedRate]
        )
        let utc = try #require(TimeZone(identifier: "UTC"))
        let start = try #require(date(year: 2026, month: 9, day: 1, hour: 0, minute: 30, in: utc))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(try stockholmJob.applicablePayRate(for: shift) == datedRate)
        #expect(try newYorkJob.applicablePayRate(for: shift) == initialRate)
    }

    @Test("Ночная смена использует только дату начала")
    func usesOnlyOvernightShiftStartDate() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(payRates: [initialRate, datedRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 8, day: 31, hour: 23, in: stockholm))
        let end = try #require(date(year: 2026, month: 9, day: 1, hour: 7, in: stockholm))
        let shift = try Shift(start: start, end: end)

        #expect(try job.applicablePayRate(for: shift) == initialRate)
    }

    @Test("Нормализация Job делает порядок входных ставок несущественным")
    func normalizesUnsortedInputRatesBeforeResolution() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 140,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )
        let job = try makeJob(payRates: [octoberRate, initialRate, septemberRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 10, day: 15, hour: 8, in: stockholm))
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

        #expect(job.payRates == [initialRate, septemberRate, octoberRate])
        #expect(try job.applicablePayRate(for: shift) == octoberRate)
    }

    private func makeJob(
        timeZoneIdentifier: String = "Europe/Stockholm",
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: payRates,
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
