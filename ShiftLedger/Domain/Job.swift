import Foundation

struct Job: Equatable {
    let id: UUID
    let currencyCode: String
    let timeZoneIdentifier: String
    let payCalculationCycle: PayCalculationCycle
    let createdAt: Date
    let workTypes: [WorkType]

    private struct ValidatedMetadata {
        let currencyCode: String
        let timeZoneIdentifier: String
    }

    var soleWorkType: WorkType? {
        guard workTypes.count == 1 else {
            return nil
        }
        return workTypes[0]
    }

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        basePayBasis: BasePayBasis,
        workTypeName: String? = nil,
        payCalculationCycle: PayCalculationCycle,
        payRates: [PayRate],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
        let metadata = try Self.validateMetadata(
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let payRateHistory = try Self.makePayRateHistory(from: payRates)
        let workType = WorkType(
            id: id,
            name: workTypeName,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory
        )

        try Self.validateWorkTypes([workType])
        self.init(
            id: id,
            metadata: metadata,
            payCalculationCycle: payCalculationCycle,
            workTypes: [workType],
            createdAt: createdAt
        )
    }

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        payCalculationCycle: PayCalculationCycle,
        workTypes: [WorkType],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let context = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: workTypes
        )
        try JobValidationChain().validate(context)

        self.init(
            id: id,
            metadata: ValidatedMetadata(
                currencyCode: normalizedCurrencyCode,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            payCalculationCycle: payCalculationCycle,
            workTypes: workTypes,
            createdAt: createdAt
        )
    }

    private init(
        id: UUID,
        metadata: ValidatedMetadata,
        payCalculationCycle: PayCalculationCycle,
        workTypes: [WorkType],
        createdAt: Date
    ) {
        self.id = id
        self.currencyCode = metadata.currencyCode
        self.timeZoneIdentifier = metadata.timeZoneIdentifier
        self.payCalculationCycle = payCalculationCycle
        self.createdAt = createdAt
        self.workTypes = workTypes.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    func workType(id: UUID) -> WorkType? {
        workTypes.first { $0.id == id }
    }

    func renamingWorkType(
        id workTypeID: UUID,
        to rawName: String
    ) throws(JobWorkTypeRenameError) -> Job {
        guard let index = workTypes.firstIndex(where: { $0.id == workTypeID }) else {
            throw .workTypeNotFound(workTypeID: workTypeID)
        }

        var renamedWorkTypes = workTypes
        do {
            renamedWorkTypes[index] = try workTypes[index].renamed(to: rawName)
        } catch {
            throw .invalidName(error)
        }

        return Job(
            id: id,
            metadata: ValidatedMetadata(
                currencyCode: currencyCode,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            payCalculationCycle: payCalculationCycle,
            workTypes: renamedWorkTypes,
            createdAt: createdAt
        )
    }

    func addingPayRate(
        _ payRate: PayRate,
        toWorkTypeID workTypeID: UUID,
        preservingHistoricalPayrollFor shifts: [Shift],
        asOf: Date
    ) throws(JobPayRateChangeError) -> Job {
        for shift in shifts where shift.jobID != id {
            throw .foreignShiftOwner(shiftID: shift.id, expectedJobID: id, actualJobID: shift.jobID)
        }
        guard let index = workTypes.firstIndex(where: { $0.id == workTypeID }) else {
            throw .workTypeNotFound(workTypeID: workTypeID)
        }

        var updatedWorkTypes = workTypes
        do {
            updatedWorkTypes[index] = try workTypes[index].addingPayRate(payRate)
        } catch {
            throw .invalidPayRateChange(error)
        }

        let candidateJob = Job(
            id: id,
            metadata: ValidatedMetadata(
                currencyCode: currencyCode,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            payCalculationCycle: payCalculationCycle,
            workTypes: updatedWorkTypes,
            createdAt: createdAt
        )

        let protectedShifts = shifts.filter {
            $0.workTypeID == workTypeID && $0.start <= asOf
        }.sorted(by: Self.isShiftOrderedBefore)

        for shift in protectedShifts {
            let currentRate: PayRate
            let candidateRate: PayRate
            do {
                currentRate = try applicablePayRate(for: shift)
                candidateRate = try candidateJob.applicablePayRate(for: shift)
            } catch {
                throw .payRateResolutionFailed(error)
            }
            guard currentRate.amount == candidateRate.amount else {
                throw .historicalCompensationWouldChange(workTypeID: workTypeID, shiftID: shift.id)
            }
        }

        return candidateJob
    }

    func archivingWorkType(
        id workTypeID: UUID
    ) throws(JobWorkTypeArchiveError) -> Job {
        guard let index = workTypes.firstIndex(where: { $0.id == workTypeID }) else {
            throw .workTypeNotFound(workTypeID: workTypeID)
        }

        var archivedWorkTypes = workTypes
        do {
            archivedWorkTypes[index] = try workTypes[index].archived()
        } catch {
            throw .alreadyArchived(workTypeID: workTypeID)
        }

        return Job(
            id: id,
            metadata: ValidatedMetadata(
                currencyCode: currencyCode,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            payCalculationCycle: payCalculationCycle,
            workTypes: archivedWorkTypes,
            createdAt: createdAt
        )
    }

    func validateNewShiftAssignment(
        _ shift: Shift
    ) throws(JobShiftAssignmentError) {
        guard shift.jobID == id else {
            throw .foreignShiftOwner(shiftID: shift.id, expectedJobID: id, actualJobID: shift.jobID)
        }
        guard let workType = workType(id: shift.workTypeID) else {
            throw .workTypeNotFound(workTypeID: shift.workTypeID)
        }
        guard workType.isArchived == false else {
            throw .workTypeArchived(workTypeID: shift.workTypeID)
        }
    }

    func applicablePayRate(for shift: Shift) throws(PayRateResolutionError) -> PayRate {
        try JobPayrollCalculator(job: self).applicablePayRate(for: shift)
    }

    func basePay(for shift: Shift) throws(PayRateResolutionError) -> Decimal {
        try JobPayrollCalculator(job: self).basePay(for: shift)
    }

    func payCalculationPeriod(
        for shift: Shift
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod {
        try JobPayrollCalculator(job: self).payCalculationPeriod(for: shift)
    }

    func payCalculationPeriod(
        containing date: Date
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod? {
        try JobPayrollCalculator(job: self).payCalculationPeriod(containing: date)
    }

    func contains(
        _ shift: Shift,
        in period: PayCalculationPeriod
    ) throws(ShiftMembershipError) -> Bool {
        try JobPayrollCalculator(job: self).contains(shift, in: period)
    }

    func expectedGross(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> Decimal {
        try JobPayrollCalculator(job: self).expectedGross(for: period, from: shifts)
    }

    func expectedGrossBreakdown(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> ExpectedGrossBreakdown {
        try JobPayrollCalculator(job: self).expectedGrossBreakdown(for: period, from: shifts)
    }

    func paycheckComparison(
        for period: PayCalculationPeriod,
        actualGross: ActualGross,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> PaycheckComparison {
        try JobPayrollCalculator(job: self).paycheckComparison(for: period, actualGross: actualGross, from: shifts)
    }

    private static func validateMetadata(
        currencyCode: String,
        timeZoneIdentifier: String
    ) throws(JobValidationError) -> ValidatedMetadata {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let context = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: []
        )
        let timeZoneHandler = TimeZoneValidationHandler()
        try CurrencyValidationHandler(next: timeZoneHandler).validate(context)

        return ValidatedMetadata(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    private static func validateWorkTypes(
        _ workTypes: [WorkType]
    ) throws(JobValidationError) {
        try WorkTypesValidationHandler.validate(workTypes)
    }

    private static func makePayRateHistory(
        from payRates: [PayRate]
    ) throws(JobValidationError) -> PayRateHistory {
        do {
            return try PayRateHistory(payRates: payRates)
        } catch {
            switch error {
            case .missingPayRates:
                throw JobValidationError.missingPayRates
            case .missingInitialPayRate:
                throw JobValidationError.missingInitialPayRate
            case .multipleInitialPayRates:
                throw JobValidationError.multipleInitialPayRates
            case .duplicatePayRateEffectiveFrom:
                throw JobValidationError.duplicatePayRateEffectiveFrom
            case .duplicatePayRateID:
                throw JobValidationError.duplicatePayRateID
            }
        }
    }

    static func isShiftOrderedBefore(_ lhs: Shift, _ rhs: Shift) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        if lhs.end != rhs.end {
            return lhs.end < rhs.end
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
