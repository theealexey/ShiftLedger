import Foundation

enum JobValidationError: Error, Equatable {
    case invalidCurrencyCode
    case invalidTimeZoneIdentifier
    case missingWorkTypes
    case duplicateWorkTypeID
    case missingPayRates
    case missingInitialPayRate
    case multipleInitialPayRates
    case duplicatePayRateEffectiveFrom
    case duplicatePayRateID
}

enum JobWorkTypeRenameError: Error, Equatable {
    case workTypeNotFound(workTypeID: UUID)
    case invalidName(WorkTypeNameValidationError)
}

enum JobPayRateChangeError: Error, Equatable {
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case workTypeNotFound(workTypeID: UUID)
    case invalidPayRateChange(WorkTypePayRateChangeError)
    case historicalCompensationWouldChange(workTypeID: UUID, shiftID: UUID)
    case payRateResolutionFailed(PayRateResolutionError)
}

enum JobWorkTypeArchiveError: Error, Equatable {
    case workTypeNotFound(workTypeID: UUID)
    case alreadyArchived(workTypeID: UUID)
}

enum JobShiftAssignmentError: Error, Equatable {
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case workTypeNotFound(workTypeID: UUID)
    case workTypeArchived(workTypeID: UUID)
}

enum PayRateResolutionError: Error, Equatable {
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case workTypeNotFound(workTypeID: UUID)
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
}

enum ExpectedGrossCalculationError: Error, Equatable {
    case membershipFailed(ShiftMembershipError)
    case basePayFailed(PayRateResolutionError)
}
