import Foundation
import CoreData

enum JobStorageError: Error {
    enum Corruption: Error {
        case unknownPayPeriodKind(String)
        case missingPayPeriodAnchorDate(payPeriodKind: String)
        case unexpectedPayPeriodAnchorDate(payPeriodKind: String)
        case invalidPayRatesRelationship
        case invalidPayRate(underlying: Error)
        case invalidJob(underlying: Error)
    }

    case jobAlreadyExists
    case multipleJobsFound
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case corruptedData(Corruption)
}

@MainActor
final class JobStorage {
    private enum StoredPayPeriodKind: String {
        case weekly
        case biweekly
        case calendarMonthly
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

        let jobEntity = JobEntity(context: context)
        jobEntity.id = job.id
        jobEntity.name = job.name
        jobEntity.currencyCode = job.currencyCode
        jobEntity.timeZoneIdentifier = job.timeZoneIdentifier
        jobEntity.createdAt = job.createdAt

        switch job.payPeriodSchedule {
        case let .weekly(anchorDate):
            jobEntity.payPeriodKind = StoredPayPeriodKind.weekly.rawValue
            jobEntity.payPeriodAnchorDate = anchorDate
        case let .biweekly(anchorDate):
            jobEntity.payPeriodKind = StoredPayPeriodKind.biweekly.rawValue
            jobEntity.payPeriodAnchorDate = anchorDate
        case .calendarMonthly:
            jobEntity.payPeriodKind = StoredPayPeriodKind.calendarMonthly.rawValue
            jobEntity.payPeriodAnchorDate = nil
        }

        for payRate in job.payRates {
            let payRateEntity = PayRateEntity(context: context)
            payRateEntity.id = payRate.id
            payRateEntity.amount = NSDecimalNumber(decimal: payRate.amount)
            payRateEntity.effectiveFrom = payRate.effectiveFrom
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
        let payPeriodSchedule = try makePayPeriodSchedule(from: jobEntity)
        var payRates: [PayRate] = []

        for object in jobEntity.payRates {
            guard let payRateEntity = object as? PayRateEntity else {
                throw JobStorageError.corruptedData(.invalidPayRatesRelationship)
            }

            payRates.append(try makePayRate(from: payRateEntity))
        }

        payRates.sort {
            if $0.effectiveFrom == $1.effectiveFrom {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.effectiveFrom < $1.effectiveFrom
        }

        do {
            return try Job(
                id: jobEntity.id,
                name: jobEntity.name,
                currencyCode: jobEntity.currencyCode,
                timeZoneIdentifier: jobEntity.timeZoneIdentifier,
                payPeriodSchedule: payPeriodSchedule,
                payRates: payRates,
                createdAt: jobEntity.createdAt
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidJob(underlying: error))
        }
    }

    private func makePayPeriodSchedule(from jobEntity: JobEntity) throws -> PayPeriodSchedule {
        guard let storedKind = StoredPayPeriodKind(rawValue: jobEntity.payPeriodKind) else {
            throw JobStorageError.corruptedData(.unknownPayPeriodKind(jobEntity.payPeriodKind))
        }

        switch storedKind {
        case .weekly:
            guard let anchorDate = jobEntity.payPeriodAnchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .weekly(anchorDate: anchorDate)
        case .biweekly:
            guard let anchorDate = jobEntity.payPeriodAnchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .biweekly(anchorDate: anchorDate)
        case .calendarMonthly:
            guard jobEntity.payPeriodAnchorDate == nil else {
                throw JobStorageError.corruptedData(
                    .unexpectedPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .calendarMonthly
        }
    }

    private func makePayRate(from payRateEntity: PayRateEntity) throws -> PayRate {
        do {
            return try PayRate(
                id: payRateEntity.id,
                amount: payRateEntity.amount.decimalValue,
                effectiveFrom: payRateEntity.effectiveFrom
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRate(underlying: error))
        }
    }
}
