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
        case invalidPayRatesRelationship
        case invalidPayRateEffectiveFrom(underlying: LocalDateConversionError)
        case invalidPayRate(underlying: PayRateValidationError)
        case nonCanonicalPayRateEffectiveFrom
        case invalidJob(underlying: JobValidationError)
    }

    case jobAlreadyExists
    case multipleJobsFound
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case corruptedData(Corruption)
}

private enum ManagedObjectCreationError: Error {
    case missingJobEntityDescription
    case missingPayRateEntityDescription
}

@MainActor
final class JobStorage {
    private enum StoredPayPeriodKind: String {
        case weekly
        case biweekly
        case calendarMonthly
        case perShift
    }

    private enum StoredBasePayKind: String {
        case hourly
        case fixedPerShift
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
        let storedPayRates = try job.payRates.map { payRate in
            (
                payRate: payRate,
                effectiveFrom: try payRate.effectiveFrom.map { try $0.startOfDay(in: timeZone) }
            )
        }

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

        let jobEntity = JobEntity(entity: jobEntityDescription, insertInto: context)
        jobEntity.id = job.id
        jobEntity.currencyCode = job.currencyCode
        jobEntity.timeZoneIdentifier = job.timeZoneIdentifier
        jobEntity.basePayKind = encodeBasePayBasis(job.basePayBasis).rawValue
        jobEntity.createdAt = job.createdAt
        jobEntity.payPeriodKind = storedPayPeriod.kind.rawValue
        jobEntity.payPeriodAnchorDate = storedPayPeriod.anchorDate

        for storedPayRate in storedPayRates {
            let payRate = storedPayRate.payRate
            let payRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            payRateEntity.id = payRate.id
            payRateEntity.amount = NSDecimalNumber(decimal: payRate.amount)
            payRateEntity.effectiveFrom = storedPayRate.effectiveFrom
            payRateEntity.job = jobEntity
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw JobStorageError.saveFailed(underlying: error)
        }
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
        let basePayBasis = try makeBasePayBasis(from: jobEntity)
        let payCalculationCycle = try makePayCalculationCycle(from: jobEntity, timeZone: timeZone)
        var payRates: [PayRate] = []

        for object in jobEntity.payRates {
            guard let payRateEntity = object as? PayRateEntity else {
                throw JobStorageError.corruptedData(.invalidPayRatesRelationship)
            }

            payRates.append(try makePayRate(from: payRateEntity, timeZone: timeZone))
        }

        do {
            return try Job(
                id: jobEntity.id,
                currencyCode: jobEntity.currencyCode,
                timeZoneIdentifier: jobEntity.timeZoneIdentifier,
                basePayBasis: basePayBasis,
                payCalculationCycle: payCalculationCycle,
                payRates: payRates,
                createdAt: jobEntity.createdAt
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidJob(underlying: error))
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

    private func makeBasePayBasis(from jobEntity: JobEntity) throws -> BasePayBasis {
        guard let rawValue = jobEntity.basePayKind else {
            return .hourly
        }

        guard let storedKind = StoredBasePayKind(rawValue: rawValue) else {
            throw JobStorageError.corruptedData(.unknownBasePayKind(rawValue))
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
