import Foundation

enum PayPeriodSchedule: Equatable {
    case weekly(anchorDate: LocalDate)
    case biweekly(anchorDate: LocalDate)
    case calendarMonthly
}
