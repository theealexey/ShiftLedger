import Foundation
import Testing
@testable import ShiftLedger

struct BaseShiftPayTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Почасовая оплата без перерыва")
    func calculatesHourlyPayWithoutBreak() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .hourly, payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(try job.basePay(for: shift) == Decimal(160))
    }

    @Test("Почасовая оплата использует оплачиваемую длительность")
    func calculatesHourlyPayWithUnpaidBreak() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .hourly, payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * hour),
                end: start.addingTimeInterval(4.5 * hour)
            )
        )

        #expect(try job.basePay(for: shift) == Decimal(150))
    }

    @Test("Фиксированная ставка применяется один раз")
    func calculatesFixedPayWithoutBreak() throws {
        let payRate = try PayRate(amount: 180, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .fixedPerShift, payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(try job.basePay(for: shift) == Decimal(180))
    }

    @Test("Перерыв не уменьшает фиксированную оплату")
    func keepsFixedPayWithUnpaidBreak() throws {
        let payRate = try PayRate(amount: 180, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .fixedPerShift, payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(3 * hour),
                end: start.addingTimeInterval(5 * hour)
            )
        )

        #expect(try job.basePay(for: shift) == Decimal(180))
    }

    @Test("Расчёт использует историческую ставку Job")
    func composesHistoricalRateResolution() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(
            basePayBasis: .hourly,
            payRates: [initialRate, datedRate]
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 9, day: 2, hour: 8, in: stockholm)
        )
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(try job.basePay(for: shift) == Decimal(200))
    }

    @Test("Ночная смена использует ставку даты начала")
    func usesStartRateAcrossOvernightEffectiveDateBoundary() throws {
        let initialRate = try PayRate(amount: 20, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 25,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let job = try makeJob(
            basePayBasis: .hourly,
            payRates: [initialRate, datedRate]
        )
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 8, day: 31, hour: 23, in: stockholm)
        )
        let end = try #require(
            date(year: 2026, month: 9, day: 1, hour: 7, in: stockholm)
        )
        let shift = try Shift(start: start, end: end)

        #expect(try job.basePay(for: shift) == Decimal(160))
    }

    @Test("Дробные ставка и часы не округляются")
    func preservesFractionalRateAndHours() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let amount = try #require(Decimal(string: "17.125", locale: locale))
        let expectedPay = try #require(Decimal(string: "25.6875", locale: locale))
        let payRate = try PayRate(amount: amount, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .hourly, payRates: [payRate])
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(1.5 * hour)
        )

        #expect(try job.basePay(for: shift) == expectedPay)
    }

    @Test("Весенний DST использует фактические оплачиваемые часы")
    func composesPaidDurationAcrossSpringForward() throws {
        let payRate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try makeJob(basePayBasis: .hourly, payRates: [payRate])
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(
            date(year: 2026, month: 3, day: 29, hour: 0, in: stockholm)
        )
        let end = try #require(
            date(year: 2026, month: 3, day: 29, hour: 8, in: stockholm)
        )
        let shift = try Shift(start: start, end: end)

        #expect(try job.basePay(for: shift) == Decimal(140))
    }

    private func makeJob(
        basePayBasis: BasePayBasis,
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
