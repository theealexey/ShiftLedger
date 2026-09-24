import Foundation
import CoreData

enum JobStorageError: Error {
    enum Corruption: Error {
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

    case jobAlreadyExists
    case jobNotFound
    case multipleJobsFound
    case invalidWorkTypeAddition(underlying: JobValidationError)
    case workTypeNotFound(workTypeID: UUID)
    case invalidWorkTypeName(underlying: WorkTypeNameValidationError)
    case invalidPayRateChange(underlying: WorkTypePayRateChangeError)
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case corruptedData(Corruption)
}

private enum ManagedObjectCreationError: Error {
    case missingJobEntityDescription
    case missingWorkTypeEntityDescription
    case missingPayRateEntityDescription
}

@MainActor
final class JobStorage {
    private struct StoredPayRate {
        let payRate: PayRate
        let effectiveFrom: Date?
    }

    private struct StoredWorkType {
        let workType: WorkType
        let basePayKind: StoredBasePayKind
        let payRates: [StoredPayRate]
    }

    private enum StoredPayPeriodKind: String {
        case weekly
        case biweekly
        case calendarMonthly
        case perShift
    }

    private let context: NSManagedObjectContext

    init(stack: CoreDataStack) {
        context = stack.viewContext
    }

    func save(_ job: Job) throws {
        switch try fetchJobs().count {
        case 0:
            break
        case 1:
            throw JobStorageError.jobAlreadyExists
        default:
            throw JobStorageError.multipleJobsFound
        }

        let timeZone = try makeTimeZone(from: job.timeZoneIdentifier)
        let storedPayPeriod = try encodePayCalculationCycle(job.payCalculationCycle, timeZone: timeZone)
        let storedWorkTypes = try prepareStoredWorkTypes(job.workTypes, timeZone: timeZone)

        guard let jobEntityDescription = NSEntityDescription.entity(
            forEntityName: "JobEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingJobEntityDescription
            )
        }
        guard let payRateEntityDescription = NSEntityDescription.entity(
            forEntityName: "PayRateEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingPayRateEntityDescription
            )
        }
        guard let workTypeEntityDescription = NSEntityDescription.entity(
            forEntityName: "WorkTypeEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingWorkTypeEntityDescription
            )
        }

        let jobEntity = JobEntity(entity: jobEntityDescription, insertInto: context)
        jobEntity.id = job.id
        jobEntity.currencyCode = job.currencyCode
        jobEntity.timeZoneIdentifier = job.timeZoneIdentifier
        jobEntity.basePayKind = storedWorkTypes.count == 1
            ? storedWorkTypes[0].basePayKind.rawValue
            : nil
        jobEntity.createdAt = job.createdAt
        jobEntity.payPeriodKind = storedPayPeriod.kind.rawValue
        jobEntity.payPeriodAnchorDate = storedPayPeriod.anchorDate

        for storedWorkType in storedWorkTypes {
            insert(
                storedWorkType,
                into: jobEntity,
                workTypeEntityDescription: workTypeEntityDescription,
                payRateEntityDescription: payRateEntityDescription
            )
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw JobStorageError.saveFailed(underlying: error)
        }
    }

    func addWorkType(_ workType: WorkType) throws -> Job {
        let jobEntities = try fetchJobs()
        let jobEntity: JobEntity
        switch jobEntities.count {
        case 0:
            throw JobStorageError.jobNotFound
        case 1:
            jobEntity = jobEntities[0]
        default:
            throw JobStorageError.multipleJobsFound
        }

        let existingJob = try makeJob(from: jobEntity)
        let candidateJob: Job
        do {
            candidateJob = try Job(
                id: existingJob.id,
                currencyCode: existingJob.currencyCode,
                timeZoneIdentifier: existingJob.timeZoneIdentifier,
                payCalculationCycle: existingJob.payCalculationCycle,
                workTypes: existingJob.workTypes + [workType],
                createdAt: existingJob.createdAt
            )
        } catch {
            throw JobStorageError.invalidWorkTypeAddition(underlying: error)
        }

        let timeZone = try makeTimeZone(from: existingJob.timeZoneIdentifier)
        let storedWorkType = try prepareStoredWorkType(workType, timeZone: timeZone)

        guard let payRateEntityDescription = NSEntityDescription.entity(
            forEntityName: "PayRateEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingPayRateEntityDescription
            )
        }
        guard let workTypeEntityDescription = NSEntityDescription.entity(
            forEntityName: "WorkTypeEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingWorkTypeEntityDescription
            )
        }

        insert(
            storedWorkType,
            into: jobEntity,
            workTypeEntityDescription: workTypeEntityDescription,
            payRateEntityDescription: payRateEntityDescription
        )
        jobEntity.basePayKind = nil

        do {
            try context.save()
        } catch {
            context.rollback()
            throw JobStorageError.saveFailed(underlying: error)
        }

        return candidateJob
    }

    func renameWorkType(id workTypeID: UUID, to rawName: String) throws -> Job {
        let jobEntities = try fetchJobs()
        let jobEntity: JobEntity
        switch jobEntities.count {
        case 0:
            throw JobStorageError.jobNotFound
        case 1:
            jobEntity = jobEntities[0]
        default:
            throw JobStorageError.multipleJobsFound
        }

        let existingJob = try makeJob(from: jobEntity)
        let candidateJob: Job
        do {
            candidateJob = try existingJob.renamingWorkType(id: workTypeID, to: rawName)
        } catch {
            switch error {
            case let .workTypeNotFound(id):
                throw JobStorageError.workTypeNotFound(workTypeID: id)
            case let .invalidName(underlying):
                throw JobStorageError.invalidWorkTypeName(underlying: underlying)
            }
        }

        guard let normalizedName = candidateJob.workType(id: workTypeID)?.name else {
            throw JobStorageError.corruptedData(.missingWorkType)
        }
        guard let workTypeEntity = try workTypeEntities(for: jobEntity)
            .first(where: { $0.id == workTypeID }) else {
            throw JobStorageError.corruptedData(.missingWorkType)
        }

        workTypeEntity.name = normalizedName
        do {
            try context.save()
        } catch {
            context.rollback()
            throw JobStorageError.saveFailed(underlying: error)
        }

        return candidateJob
    }

    func addPayRate(_ payRate: PayRate, toWorkTypeID workTypeID: UUID) throws -> Job {
        let jobEntities = try fetchJobs()
        let jobEntity: JobEntity
        switch jobEntities.count {
        case 0:
            throw JobStorageError.jobNotFound
        case 1:
            jobEntity = jobEntities[0]
        default:
            throw JobStorageError.multipleJobsFound
        }

        let existingJob = try makeJob(from: jobEntity)
        let candidateJob: Job
        do {
            candidateJob = try existingJob.addingPayRate(payRate, toWorkTypeID: workTypeID)
        } catch {
            switch error {
            case let .workTypeNotFound(id):
                throw JobStorageError.workTypeNotFound(workTypeID: id)
            case let .invalidPayRateChange(underlying):
                throw JobStorageError.invalidPayRateChange(underlying: underlying)
            }
        }

        guard let workTypeEntity = try workTypeEntities(for: jobEntity)
            .first(where: { $0.id == workTypeID }) else {
            throw JobStorageError.corruptedData(.missingWorkType)
        }
        let timeZone = try makeTimeZone(from: existingJob.timeZoneIdentifier)
        let storedPayRate = try prepareStoredPayRate(payRate, timeZone: timeZone)
        guard let payRateEntityDescription = NSEntityDescription.entity(
            forEntityName: "PayRateEntity",
            in: context
        ) else {
            throw JobStorageError.saveFailed(
                underlying: ManagedObjectCreationError.missingPayRateEntityDescription
            )
        }

        let payRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
        payRateEntity.id = storedPayRate.payRate.id
        payRateEntity.amount = NSDecimalNumber(decimal: storedPayRate.payRate.amount)
        payRateEntity.effectiveFrom = storedPayRate.effectiveFrom
        payRateEntity.job = jobEntity
        payRateEntity.workType = workTypeEntity

        do {
            try context.save()
        } catch {
            context.rollback()
            throw JobStorageError.saveFailed(underlying: error)
        }

        return candidateJob
    }

    func load() throws -> Job? {
        let jobEntities = try fetchJobs()

        switch jobEntities.count {
        case 0:
            return nil
        case 1:
            return try makeJob(from: jobEntities[0])
        default:
            throw JobStorageError.multipleJobsFound
        }
    }

    private func fetchJobs() throws -> [JobEntity] {
        let request = NSFetchRequest<JobEntity>(entityName: "JobEntity")
        request.fetchLimit = 2

        do {
            return try context.fetch(request)
        } catch {
            throw JobStorageError.fetchFailed(underlying: error)
        }
    }

    private func makeJob(from jobEntity: JobEntity) throws -> Job {
        let timeZone = try makeTimeZone(from: jobEntity.timeZoneIdentifier)
        let workTypeEntities = try workTypeEntities(for: jobEntity)
        let workTypes = try workTypeEntities.map {
            try makeWorkType(from: $0, jobEntity: jobEntity, timeZone: timeZone)
        }
        let payCalculationCycle = try makePayCalculationCycle(from: jobEntity, timeZone: timeZone)

        do {
            return try Job(
                id: jobEntity.id,
                currencyCode: jobEntity.currencyCode,
                timeZoneIdentifier: jobEntity.timeZoneIdentifier,
                payCalculationCycle: payCalculationCycle,
                workTypes: workTypes,
                createdAt: jobEntity.createdAt
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidJob(underlying: error))
        }
    }

    private func prepareStoredWorkTypes(
        _ workTypes: [WorkType],
        timeZone: TimeZone
    ) throws -> [StoredWorkType] {
        try workTypes.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            try prepareStoredWorkType($0, timeZone: timeZone)
        }
    }

    private func prepareStoredWorkType(
        _ workType: WorkType,
        timeZone: TimeZone
    ) throws -> StoredWorkType {
        let payRates = try workType.payRates.map { payRate in
            try prepareStoredPayRate(payRate, timeZone: timeZone)
        }

        return StoredWorkType(
            workType: workType,
            basePayKind: encodeBasePayBasis(workType.basePayBasis),
            payRates: payRates
        )
    }

    private func prepareStoredPayRate(
        _ payRate: PayRate,
        timeZone: TimeZone
    ) throws -> StoredPayRate {
        StoredPayRate(
            payRate: payRate,
            effectiveFrom: try payRate.effectiveFrom.map {
                try $0.startOfDay(in: timeZone)
            }
        )
    }

    private func insert(
        _ storedWorkType: StoredWorkType,
        into jobEntity: JobEntity,
        workTypeEntityDescription: NSEntityDescription,
        payRateEntityDescription: NSEntityDescription
    ) {
        let workTypeEntity = WorkTypeEntity(
            entity: workTypeEntityDescription,
            insertInto: context
        )
        workTypeEntity.id = storedWorkType.workType.id
        workTypeEntity.name = storedWorkType.workType.name
        workTypeEntity.basePayKind = storedWorkType.basePayKind.rawValue
        workTypeEntity.job = jobEntity

        for storedPayRate in storedWorkType.payRates {
            let payRate = storedPayRate.payRate
            let payRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            payRateEntity.id = payRate.id
            payRateEntity.amount = NSDecimalNumber(decimal: payRate.amount)
            payRateEntity.effectiveFrom = storedPayRate.effectiveFrom
            payRateEntity.job = jobEntity
            payRateEntity.workType = workTypeEntity
        }
    }

    private func encodeBasePayBasis(_ basis: BasePayBasis) -> StoredBasePayKind {
        switch basis {
        case .hourly:
            .hourly
        case .fixedPerShift:
            .fixedPerShift
        }
    }

    private func workTypeEntities(for jobEntity: JobEntity) throws -> [WorkTypeEntity] {
        var workTypes: [WorkTypeEntity] = []
        for object in jobEntity.workTypes ?? NSSet() {
            guard let workTypeEntity = object as? WorkTypeEntity else {
                throw JobStorageError.corruptedData(.invalidWorkTypesRelationship)
            }
            workTypes.append(workTypeEntity)
        }

        guard workTypes.isEmpty == false else {
            throw JobStorageError.corruptedData(.missingWorkType)
        }

        return workTypes.sorted(by: isWorkTypeEntityOrderedBefore)
    }

    private func makeWorkType(
        from workTypeEntity: WorkTypeEntity,
        jobEntity: JobEntity,
        timeZone: TimeZone
    ) throws -> WorkType {
        guard workTypeEntity.job.objectID == jobEntity.objectID else {
            throw JobStorageError.corruptedData(
                .workTypeBelongsToDifferentJob(
                    workTypeID: workTypeEntity.id,
                    expectedJobID: jobEntity.id,
                    actualJobID: workTypeEntity.job.id
                )
            )
        }

        let basePayBasis = try makeBasePayBasis(from: workTypeEntity)
        let payRateEntities = try payRateEntities(for: workTypeEntity)
        var payRates: [PayRate] = []

        for payRateEntity in payRateEntities {
            guard payRateEntity.job.objectID == jobEntity.objectID else {
                throw JobStorageError.corruptedData(
                    .payRateBelongsToDifferentJob(
                        payRateID: payRateEntity.id,
                        expectedJobID: jobEntity.id,
                        actualJobID: payRateEntity.job.id
                    )
                )
            }

            payRates.append(try makePayRate(from: payRateEntity, timeZone: timeZone))
        }

        let payRateHistory: PayRateHistory
        do {
            payRateHistory = try PayRateHistory(payRates: payRates)
        } catch {
            throw JobStorageError.corruptedData(
                .invalidJob(underlying: mapPayRateHistoryValidationError(error))
            )
        }

        return WorkType(
            id: workTypeEntity.id,
            name: workTypeEntity.name,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory
        )
    }

    private func payRateEntities(for workTypeEntity: WorkTypeEntity) throws -> [PayRateEntity] {
        var payRates: [PayRateEntity] = []
        for object in workTypeEntity.payRates ?? NSSet() {
            guard let payRateEntity = object as? PayRateEntity else {
                throw JobStorageError.corruptedData(.invalidWorkTypePayRatesRelationship)
            }
            payRates.append(payRateEntity)
        }

        return payRates.sorted(by: isPayRateEntityOrderedBefore)
    }

    private func isWorkTypeEntityOrderedBefore(
        _ lhs: WorkTypeEntity,
        _ rhs: WorkTypeEntity
    ) -> Bool {
        if lhs.id != rhs.id {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.objectID.uriRepresentation().absoluteString
            < rhs.objectID.uriRepresentation().absoluteString
    }

    private func isPayRateEntityOrderedBefore(
        _ lhs: PayRateEntity,
        _ rhs: PayRateEntity
    ) -> Bool {
        if lhs.id != rhs.id {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.objectID.uriRepresentation().absoluteString
            < rhs.objectID.uriRepresentation().absoluteString
    }

    private func mapPayRateHistoryValidationError(
        _ error: PayRateHistoryValidationError
    ) -> JobValidationError {
        switch error {
        case .missingPayRates:
            .missingPayRates
        case .missingInitialPayRate:
            .missingInitialPayRate
        case .multipleInitialPayRates:
            .multipleInitialPayRates
        case .duplicatePayRateEffectiveFrom:
            .duplicatePayRateEffectiveFrom
        case .duplicatePayRateID:
            .duplicatePayRateID
        }
    }

    private func makeBasePayBasis(from workTypeEntity: WorkTypeEntity) throws -> BasePayBasis {
        guard let storedKind = StoredBasePayKind(rawValue: workTypeEntity.basePayKind) else {
            throw JobStorageError.corruptedData(
                .unknownBasePayKind(workTypeEntity.basePayKind)
            )
        }

        switch storedKind {
        case .hourly:
            return .hourly
        case .fixedPerShift:
            return .fixedPerShift
        }
    }

    private func encodePayCalculationCycle(
        _ payCalculationCycle: PayCalculationCycle,
        timeZone: TimeZone
    ) throws -> (kind: StoredPayPeriodKind, anchorDate: Date?) {
        switch payCalculationCycle {
        case .perShift:
            return (.perShift, nil)
        case let .scheduled(schedule):
            switch schedule {
            case let .weekly(anchorDate):
                return (.weekly, try anchorDate.startOfDay(in: timeZone))
            case let .biweekly(anchorDate):
                return (.biweekly, try anchorDate.startOfDay(in: timeZone))
            case .calendarMonthly:
                return (.calendarMonthly, nil)
            }
        }
    }

    private func makePayCalculationCycle(
        from jobEntity: JobEntity,
        timeZone: TimeZone
    ) throws -> PayCalculationCycle {
        guard let storedKind = StoredPayPeriodKind(rawValue: jobEntity.payPeriodKind) else {
            throw JobStorageError.corruptedData(.unknownPayPeriodKind(jobEntity.payPeriodKind))
        }

        switch storedKind {
        case .perShift:
            guard jobEntity.payPeriodAnchorDate == nil else {
                throw JobStorageError.corruptedData(
                    .unexpectedPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .perShift
        case .weekly:
            guard let anchorDate = jobEntity.payPeriodAnchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(
                .weekly(
                    anchorDate: try makePayPeriodAnchorDate(
                        from: anchorDate,
                        kind: storedKind,
                        timeZone: timeZone
                    )
                )
            )
        case .biweekly:
            guard let anchorDate = jobEntity.payPeriodAnchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(
                .biweekly(
                    anchorDate: try makePayPeriodAnchorDate(
                        from: anchorDate,
                        kind: storedKind,
                        timeZone: timeZone
                    )
                )
            )
        case .calendarMonthly:
            guard jobEntity.payPeriodAnchorDate == nil else {
                throw JobStorageError.corruptedData(
                    .unexpectedPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(.calendarMonthly)
        }
    }

    private func makeTimeZone(from identifier: String) throws -> TimeZone {
        guard
            TimeZone.knownTimeZoneIdentifiers.contains(identifier),
            let timeZone = TimeZone(identifier: identifier)
        else {
            throw JobStorageError.corruptedData(.invalidTimeZoneIdentifier(identifier))
        }

        return timeZone
    }

    private func makePayPeriodAnchorDate(
        from storedDate: Date,
        kind: StoredPayPeriodKind,
        timeZone: TimeZone
    ) throws -> LocalDate {
        let anchorDate: LocalDate

        do {
            anchorDate = try LocalDate(date: storedDate, in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(
                .invalidPayPeriodAnchorDate(payPeriodKind: kind.rawValue, underlying: error)
            )
        }

        let canonicalDate: Date
        do {
            canonicalDate = try anchorDate.startOfDay(in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(
                .invalidPayPeriodAnchorDate(payPeriodKind: kind.rawValue, underlying: error)
            )
        }

        guard canonicalDate == storedDate else {
            throw JobStorageError.corruptedData(
                .nonCanonicalPayPeriodAnchorDate(payPeriodKind: kind.rawValue)
            )
        }

        return anchorDate
    }

    private func makePayRate(
        from payRateEntity: PayRateEntity,
        timeZone: TimeZone
    ) throws -> PayRate {
        guard let storedEffectiveFrom = payRateEntity.effectiveFrom else {
            do {
                return try PayRate(
                    id: payRateEntity.id,
                    amount: payRateEntity.amount.decimalValue,
                    effectiveFrom: nil
                )
            } catch {
                throw JobStorageError.corruptedData(.invalidPayRate(underlying: error))
            }
        }

        let effectiveFrom: LocalDate

        do {
            effectiveFrom = try LocalDate(date: storedEffectiveFrom, in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRateEffectiveFrom(underlying: error))
        }

        let canonicalDate: Date
        do {
            canonicalDate = try effectiveFrom.startOfDay(in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRateEffectiveFrom(underlying: error))
        }

        guard canonicalDate == storedEffectiveFrom else {
            throw JobStorageError.corruptedData(.nonCanonicalPayRateEffectiveFrom)
        }

        do {
            return try PayRate(
                id: payRateEntity.id,
                amount: payRateEntity.amount.decimalValue,
                effectiveFrom: effectiveFrom
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRate(underlying: error))
        }
    }
}
