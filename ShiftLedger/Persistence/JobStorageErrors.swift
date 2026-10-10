import Foundation

enum JobStorageError: Error {
    enum Corruption: Error {
        case duplicateJobIdentity(jobID: UUID)
        case invalidTimeZoneIdentifier(String)
        case unknownPayPeriodKind(String)
        case unknownBasePayKind(String)
        case missingPayPeriodAnchorDate(payPeriodKind: String)
        case unexpectedPayPeriodAnchorDate(payPeriodKind: String)
        case invalidPayPeriodAnchorDate(payPeriodKind: String, underlying: LocalDateConversionError)
        case nonCanonicalPayPeriodAnchorDate(payPeriodKind: String)
        case invalidWorkTypesRelationship
        case missingWorkType
        case workTypeBelongsToDifferentJob(
            workTypeID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case invalidWorkTypePayRatesRelationship
        case payRateBelongsToDifferentJob(
            payRateID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case invalidPayRateEffectiveFrom(underlying: LocalDateConversionError)
        case invalidPayRate(underlying: PayRateValidationError)
        case nonCanonicalPayRateEffectiveFrom
        case invalidJob(underlying: JobValidationError)
    }

    case pendingContextChanges
    case jobAlreadyExists
    case jobNotFound(jobID: UUID)
    case jobArchived(jobID: UUID)
    case multipleJobsFound
    case invalidWorkTypeAddition(underlying: JobValidationError)
    case workTypeNotFound(workTypeID: UUID)
    case workTypeAlreadyArchived(workTypeID: UUID)
    case invalidWorkTypeName(underlying: WorkTypeNameValidationError)
    case invalidPayRateChange(underlying: WorkTypePayRateChangeError)
    case historicalCompensationWouldChange(workTypeID: UUID, shiftID: UUID)
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case payRateResolutionFailed(underlying: PayRateResolutionError)
    case shiftLoadFailed(underlying: ShiftStorageError)
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case corruptedData(Corruption)
}
