import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftHistoryQueryTests {
    private let locale = Locale(identifier: "en_US")
    private let jobID = UUID()
    private let workID = UUID()
    private let otherWorkID = UUID()

    @Test func sortingUsesExactAmountsAndDeterministicTies() throws {
        let first = try row(id: 1, start: 0, amount: "1.004")
        let second = try row(id: 2, start: 10_000, amount: "1.003")
        let third = try row(id: 3, start: 10_000, amount: "1.003")
        let longer = try row(id: 4, start: 10_000, duration: 4_000, amount: "1.003")
        let rows = [third, first, longer, second]
        let now = Date(timeIntervalSince1970: 0)
        #expect(try ShiftHistoryQuery().results(rows, now: now, timeZone: .gmt) == [longer, third, second, first])
        #expect(try ShiftHistoryQuery(sort: .oldest).results(rows, now: now, timeZone: .gmt) == [first, second, third, longer])
        #expect(try ShiftHistoryQuery(sort: .highest).results(rows, now: now, timeZone: .gmt) == [first, longer, third, second])
        #expect(try ShiftHistoryQuery(sort: .lowest).results(rows, now: now, timeZone: .gmt) == [longer, third, second, first])
        #expect(OverviewFormatting.currency(first.basePay, currencyCode: "EUR", locale: locale)
                == OverviewFormatting.currency(second.basePay, currencyCode: "EUR", locale: locale))
        #expect(try ShiftHistoryQuery(minimum: first.basePay).results(rows, now: now, timeZone: .gmt) == [first])
        #expect(try ShiftHistoryQuery(maximum: second.basePay).results(rows, now: now, timeZone: .gmt) == [longer, third, second])
    }

    @Test(arguments: [(3, 29, 23), (10, 25, 25)])
    func inclusiveSingleDayAcrossDST(month: Int, day: Int, hours: Int) throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let local = try LocalDate(year: 2026, month: month, day: day)
        let first = try local.startOfDay(in: zone)
        let next = try local.addingDays(1).startOfDay(in: zone)
        let before = try row(id: 1, start: first.timeIntervalSince1970 - 60, amount: "2")
        let atStart = try row(id: 2, start: first.timeIntervalSince1970, amount: "1")
        let late = try row(id: 3, start: next.timeIntervalSince1970 - 60, amount: "2", workType: otherWorkID)
        let atEnd = try row(id: 4, start: next.timeIntervalSince1970, amount: "2")
        let outsideType = try row(id: 5, start: first.timeIntervalSince1970, amount: "2", workType: UUID())
        let dateOnly = ShiftHistoryQuery(dates: .custom(local, local))
        #expect(try dateOnly.dateBounds(now: first, timeZone: zone) == first..<next)
        #expect(next.timeIntervalSince(first) == Double(hours * 3600))
        let query = ShiftHistoryQuery(dates: .custom(local, local), workTypeIDs: [workID, otherWorkID], minimum: 2, maximum: 2)
        #expect(try query.results([before, atStart, late, atEnd, outsideType], now: first, timeZone: zone) == [late])
        #expect(try ShiftHistoryQuery(dates: .thisMonth).dateBounds(now: first, timeZone: zone)?.contains(first) == true)
        let yesterday = try local.addingDays(-1)
        #expect(throws: ShiftHistoryQuery.ValidationError.self) {
            try ShiftHistoryQuery(dates: .custom(local, yesterday)).dateBounds(now: first, timeZone: zone)
        }
    }

    @Test func inputMustRoundTripExactly() throws {
        let ru = Locale(identifier: "ru_RU")
        #expect(try ShiftHistoryQuery.amount("", locale: ru) == nil)
        #expect(try ShiftHistoryQuery.amount("000,000", locale: ru) == 0)
        let exact = "1.00412345678901234567890123456789"
        #expect(try ShiftHistoryQuery.amount(exact.replacingOccurrences(of: ".", with: ","), locale: ru)
                == Decimal(string: exact, locale: locale))
        for invalid in ["-1", "1.2x", "3..1", "2.", "1e3", "1,2", "1 000",
                        String(repeating: "9", count: 200), "1." + String(repeating: "1", count: 50),
                        "0." + String(repeating: "0", count: 200) + "1"] {
            #expect(throws: ShiftHistoryQuery.ValidationError.self) { try ShiftHistoryQuery.amount(invalid, locale: locale) }
        }
        #expect(throws: ShiftHistoryQuery.ValidationError.self) {
            try ShiftHistoryQuery(minimum: 2, maximum: 1).results([], now: .now, timeZone: .gmt)
        }
    }

    private func row(id: UInt8, start: TimeInterval, duration: TimeInterval = 3600, amount: String,
                     workType: UUID? = nil) throws -> ShiftPayBreakdown {
        let date = Date(timeIntervalSince1970: start)
        let shift = try Shift(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
                              jobID: jobID, workTypeID: workType ?? workID,
                              start: date, end: date.addingTimeInterval(duration))
        let exact = try #require(Decimal(string: amount, locale: locale))
        return ShiftPayBreakdown(shift: shift, basePayBasis: .fixedPerShift,
                                 appliedPayRate: try PayRate(amount: exact, effectiveFrom: nil),
                                 paidDuration: duration, basePay: exact)
    }
}
