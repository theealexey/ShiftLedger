import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftTests {
    private let start = Date(timeIntervalSinceReferenceDate: 100_000)

    @Test("Обычная смена валидна")
    func acceptsNormalShift() throws {
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * 60 * 60))
        #expect(shift.start == start)
    }

    @Test("Ночная смена валидна")
    func acceptsOvernightShift() throws {
        let shift = try Shift(start: start, end: start.addingTimeInterval(10 * 60 * 60))
        #expect(shift.end > shift.start)
    }

    @Test("Начало не раньше конца")
    func rejectsInvalidOrder() {
        #expect(throws: ShiftValidationError.startNotBeforeEnd) {
            try Shift(start: start, end: start)
        }
        #expect(throws: ShiftValidationError.startNotBeforeEnd) {
            try Shift(start: start, end: start.addingTimeInterval(-1))
        }
    }

    @Test("Ровно 48 часов допустимо, больше — нет")
    func enforcesMaximumDuration() throws {
        _ = try Shift(start: start, end: start.addingTimeInterval(48 * 60 * 60))
        #expect(throws: ShiftValidationError.durationExceedsLimit) {
            try Shift(start: start, end: start.addingTimeInterval(48 * 60 * 60 + 1))
        }
    }

    @Test("Смена без перерыва валидна")
    func acceptsNoBreak() throws {
        #expect(try Shift(start: start, end: start.addingTimeInterval(60)).unpaidBreak == nil)
    }

    @Test("Перерыв внутри смены и на границах валиден")
    func acceptsBreakInsideAndAtBoundaries() throws {
        _ = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(2 * 60 * 60),
                end: start.addingTimeInterval(3 * 60 * 60)
            )
        )
        _ = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start,
                end: start.addingTimeInterval(60)
            )
        )
        _ = try Shift(
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(7 * 60 * 60),
                end: start.addingTimeInterval(8 * 60 * 60)
            )
        )
    }

    @Test("Некорректный перерыв отклоняется")
    func rejectsInvalidBreaks() {
        let end = start.addingTimeInterval(8 * 60 * 60)
        #expect(throws: ShiftValidationError.breakStartNotBeforeEnd) {
            try Shift(start: start, end: end, unpaidBreak: UnpaidBreak(start: start, end: start))
        }
        #expect(throws: ShiftValidationError.breakOutsideShift) {
            try Shift(
                start: start,
                end: end,
                unpaidBreak: UnpaidBreak(start: start.addingTimeInterval(-1), end: start.addingTimeInterval(60))
            )
        }
        #expect(throws: ShiftValidationError.breakOutsideShift) {
            try Shift(
                start: start,
                end: end,
                unpaidBreak: UnpaidBreak(start: end.addingTimeInterval(-60), end: end.addingTimeInterval(1))
            )
        }
        #expect(throws: ShiftValidationError.breakConsumesEntireShift) {
            try Shift(start: start, end: end, unpaidBreak: UnpaidBreak(start: start, end: end))
        }
    }

    @Test("Полуоткрытые интервалы допускают соседние смены")
    func adjacentShiftsDoNotOverlap() throws {
        let first = try Shift(start: start, end: start.addingTimeInterval(8 * 60 * 60))
        let second = try Shift(
            start: start.addingTimeInterval(8 * 60 * 60),
            end: start.addingTimeInterval(12 * 60 * 60)
        )
        #expect(first.overlaps(with: second) == false)
    }

    @Test("Частичное, вложенное и идентичное пересечение обнаруживаются")
    func detectsOverlaps() throws {
        let base = try Shift(start: start, end: start.addingTimeInterval(8 * 60 * 60))
        let partial = try Shift(
            start: start.addingTimeInterval(7 * 60 * 60),
            end: start.addingTimeInterval(10 * 60 * 60)
        )
        let contained = try Shift(
            start: start.addingTimeInterval(2 * 60 * 60),
            end: start.addingTimeInterval(3 * 60 * 60)
        )
        let identical = try Shift(start: start, end: start.addingTimeInterval(8 * 60 * 60))
        #expect(base.overlaps(with: partial))
        #expect(base.overlaps(with: contained))
        #expect(base.overlaps(with: identical))
    }

    @Test("Длительность использует абсолютные Date во время DST")
    func validatesAbsoluteDurationAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)))

        #expect(end.timeIntervalSince(start) == 49 * 60 * 60)
        #expect(throws: ShiftValidationError.durationExceedsLimit) {
            try Shift(start: start, end: end)
        }
    }
}
