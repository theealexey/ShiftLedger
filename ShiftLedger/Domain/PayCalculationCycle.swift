import Foundation

enum PayCalculationCycle: Equatable {
    case perShift
    case scheduled(PayPeriodSchedule)
}

enum PayCalculationPeriod: Equatable {
    case perShift(shiftID: UUID)
    case scheduled(PayPeriod)
}

enum PayCalculationPeriodResolutionError: Error, Equatable {
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
    case scheduledPeriodResolutionFailed
}

enum ShiftMembershipError: Error, Equatable {
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
}
