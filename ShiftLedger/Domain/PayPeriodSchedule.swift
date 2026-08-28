import Foundation

enum PayPeriodSchedule: Equatable {
    case weekly(anchorDate: Date)
    case biweekly(anchorDate: Date)
    case calendarMonthly
}
