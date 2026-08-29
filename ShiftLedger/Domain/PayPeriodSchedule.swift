import Foundation

enum PayPeriodSchedule: Equatable {
    case weekly(anchorDate: LocalDate)
    case biweekly(anchorDate: LocalDate)
    case calendarMonthly

    func period(containing date: LocalDate) throws -> PayPeriod {
        switch self {
        case let .weekly(anchorDate):
            return try Self.anchoredPeriod(containing: date, anchorDate: anchorDate, lengthInDays: 7)
        case let .biweekly(anchorDate):
            return try Self.anchoredPeriod(containing: date, anchorDate: anchorDate, lengthInDays: 14)
        case .calendarMonthly:
            let start = try LocalDate(year: date.year, month: date.month, day: 1)
            return try PayPeriod(start: start, endExclusive: start.firstDayOfNextMonth())
        }
    }

    private static func anchoredPeriod(
        containing date: LocalDate,
        anchorDate: LocalDate,
        lengthInDays: Int
    ) throws -> PayPeriod {
        let dayOffset = try anchorDate.daysUntil(date)
        let periodIndex = floorDividing(dayOffset, by: lengthInDays)
        let start = try anchorDate.addingDays(periodIndex * lengthInDays)
        let endExclusive = try start.addingDays(lengthInDays)

        return PayPeriod(start: start, endExclusive: endExclusive)
    }

    private static func floorDividing(_ dividend: Int, by divisor: Int) -> Int {
        let quotient = dividend / divisor
        let remainder = dividend % divisor

        return remainder < 0 ? quotient - 1 : quotient
    }
}
