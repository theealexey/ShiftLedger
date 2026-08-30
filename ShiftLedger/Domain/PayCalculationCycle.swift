import Foundation

enum PayCalculationCycle: Equatable {
    case perShift
    case scheduled(PayPeriodSchedule)
}
