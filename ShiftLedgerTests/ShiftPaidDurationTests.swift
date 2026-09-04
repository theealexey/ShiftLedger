import Foundation
import Testing
@testable import ShiftLedger

struct ShiftPaidDurationTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Оплачиваемая длительность смены без перерыва")
    func calculatesDurationWithoutBreak() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(shift.paidDuration == 8 * hour)
    }

    @Test("Неоплачиваемый перерыв вычитается из длительности смены")
    func subtractsUnpaidBreakDuration() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * hour),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * hour),
                end: start.addingTimeInterval(4.5 * hour)
            )
        )

        #expect(shift.paidDuration == 7.5 * hour)
    }

    @Test("Ночная смена использует абсолютную длительность")
    func calculatesOvernightDuration() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            start: start,
            end: start.addingTimeInterval(12 * hour)
        )

        #expect(shift.paidDuration == 12 * hour)
    }

    @Test("Весенний переход DST использует фактическую длительность")
    func calculatesSpringForwardDuration() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 3, day: 29, hour: 0, in: timeZone))
        let end = try #require(date(year: 2026, month: 3, day: 29, hour: 8, in: timeZone))
        let shift = try Shift(start: start, end: end)

        #expect(shift.paidDuration == 7 * hour)
    }

    @Test("Осенний переход DST использует фактическую длительность")
    func calculatesFallBackDuration() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 10, day: 25, hour: 0, in: timeZone))
        let end = try #require(date(year: 2026, month: 10, day: 25, hour: 8, in: timeZone))
        let shift = try Shift(start: start, end: end)

        #expect(shift.paidDuration == 9 * hour)
    }

    @Test("Перерыв через DST вычитается по фактическому интервалу")
    func subtractsBreakAcrossSpringForwardTransition() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(date(year: 2026, month: 3, day: 29, hour: 0, in: timeZone))
        let end = try #require(date(year: 2026, month: 3, day: 29, hour: 8, in: timeZone))
        let breakStart = try #require(date(year: 2026, month: 3, day: 29, hour: 1, minute: 30, in: timeZone))
        let breakEnd = try #require(date(year: 2026, month: 3, day: 29, hour: 3, minute: 30, in: timeZone))
        let shift = try Shift(
            start: start,
            end: end,
            unpaidBreak: UnpaidBreak(start: breakStart, end: breakEnd)
        )
        let expectedDuration = end.timeIntervalSince(start)
            - breakEnd.timeIntervalSince(breakStart)

        #expect(shift.paidDuration == expectedDuration)
    }

    @Test("Дробные секунды оплачиваемой длительности не округляются")
    func preservesFractionalSecondDuration() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100_000.125)
        let end = start.addingTimeInterval(8 * hour + 0.75)
        let shift = try Shift(start: start, end: end)

        #expect(shift.paidDuration == end.timeIntervalSince(start))
        #expect(shift.paidDuration == 8 * hour + 0.75)
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
