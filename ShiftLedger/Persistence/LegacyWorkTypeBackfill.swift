import CoreData
import Foundation

enum LegacyWorkTypeBackfillError: Error {
    enum InvariantViolation: Error, Equatable {
        case duplicateJobIdentity(UUID)
        case duplicateDefaultWorkTypeIdentity(jobID: UUID)
        case defaultWorkTypeBelongsToDifferentJob(jobID: UUID, actualJobID: UUID)
        case missingDefaultWorkType(jobID: UUID, existingWorkTypeIDs: [UUID])
        case incompatibleBasePayKind(
            jobID: UUID,
            expected: String,
            actual: String
        )
        case payRateWorkTypeBelongsToDifferentJob(
            payRateID: UUID,
            workTypeID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case unknownLegacyBasePayKind(jobID: UUID, rawValue: String)
        case invalidWorkTypesRelationship(jobID: UUID)
        case invalidPayRatesRelationship(jobID: UUID)
    }

    case fetchFailed(underlying: Error)
    case missingWorkTypeEntityDescription
    case invariantViolation(InvariantViolation)
    case saveFailed(underlying: Error)
}

@MainActor
enum LegacyWorkTypeBackfill {
    static func run(
        in context: NSManagedObjectContext
    ) throws(LegacyWorkTypeBackfillError) {
        do {
            try execute(in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func execute(
        in context: NSManagedObjectContext
    ) throws(LegacyWorkTypeBackfillError) {
        let jobs: [JobEntity]
        let persistedWorkTypes: [WorkTypeEntity]

        do {
            jobs = try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
            persistedWorkTypes = try context.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            )
        } catch {
            throw .fetchFailed(underlying: error)
        }

        let jobsByID = Dictionary(grouping: jobs, by: \.id)
        if let duplicateJobID = jobsByID
            .filter({ $0.value.count > 1 })
            .map(\.key)
            .sorted(by: uuidPrecedes)
            .first {
            throw .invariantViolation(.duplicateJobIdentity(duplicateJobID))
        }

        let workTypesByID = Dictionary(grouping: persistedWorkTypes, by: \.id)
        let sortedJobs = jobs.sorted { $0.id.uuidString < $1.id.uuidString }

        for job in sortedJobs {
            let relatedWorkTypes = try workTypes(for: job)
            let relatedPayRates = try payRates(for: job)
                .sorted { uuidPrecedes($0.id, $1.id) }

            for payRate in relatedPayRates {
                guard let existingWorkType = payRate.workType else {
                    continue
                }
                guard existingWorkType.job.objectID == job.objectID else {
                    throw .invariantViolation(
                        .payRateWorkTypeBelongsToDifferentJob(
                            payRateID: payRate.id,
                            workTypeID: existingWorkType.id,
                            expectedJobID: job.id,
                            actualJobID: existingWorkType.job.id
                        )
                    )
                }
            }

            let unassignedPayRates = relatedPayRates.filter { $0.workType == nil }
            guard relatedWorkTypes.isEmpty || !unassignedPayRates.isEmpty else {
                continue
            }

            let basePayKind = try canonicalBasePayKind(for: job)
            let matchingWorkTypes = workTypesByID[job.id, default: []]

            guard matchingWorkTypes.count <= 1 else {
                throw .invariantViolation(
                    .duplicateDefaultWorkTypeIdentity(jobID: job.id)
                )
            }

            let defaultWorkType: WorkTypeEntity
            if let existingWorkType = matchingWorkTypes.first {
                guard existingWorkType.job.objectID == job.objectID else {
                    throw .invariantViolation(
                        .defaultWorkTypeBelongsToDifferentJob(
                            jobID: job.id,
                            actualJobID: existingWorkType.job.id
                        )
                    )
                }
                guard existingWorkType.basePayKind == basePayKind else {
                    throw .invariantViolation(
                        .incompatibleBasePayKind(
                            jobID: job.id,
                            expected: basePayKind,
                            actual: existingWorkType.basePayKind
                        )
                    )
                }
                defaultWorkType = existingWorkType
            } else {
                guard relatedWorkTypes.isEmpty else {
                    throw .invariantViolation(
                        .missingDefaultWorkType(
                            jobID: job.id,
                            existingWorkTypeIDs: relatedWorkTypes
                                .map(\.id)
                                .sorted { $0.uuidString < $1.uuidString }
                        )
                    )
                }
                defaultWorkType = try makeDefaultWorkType(
                    for: job,
                    basePayKind: basePayKind,
                    in: context
                )
            }

            for payRate in unassignedPayRates {
                payRate.workType = defaultWorkType
            }
        }

        guard context.hasChanges else {
            return
        }

        do {
            try context.save()
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    private static func canonicalBasePayKind(
        for job: JobEntity
    ) throws(LegacyWorkTypeBackfillError) -> String {
        guard let rawValue = job.basePayKind else {
            return StoredBasePayKind.hourly.rawValue
        }
        guard let storedKind = StoredBasePayKind(rawValue: rawValue) else {
            throw .invariantViolation(
                .unknownLegacyBasePayKind(jobID: job.id, rawValue: rawValue)
            )
        }
        return storedKind.rawValue
    }

    private static func workTypes(
        for job: JobEntity
    ) throws(LegacyWorkTypeBackfillError) -> [WorkTypeEntity] {
        var result: [WorkTypeEntity] = []
        for object in job.workTypes ?? NSSet() {
            guard let workType = object as? WorkTypeEntity else {
                throw .invariantViolation(
                    .invalidWorkTypesRelationship(jobID: job.id)
                )
            }
            result.append(workType)
        }
        return result
    }

    private static func payRates(
        for job: JobEntity
    ) throws(LegacyWorkTypeBackfillError) -> [PayRateEntity] {
        var result: [PayRateEntity] = []
        for object in job.payRates {
            guard let payRate = object as? PayRateEntity else {
                throw .invariantViolation(
                    .invalidPayRatesRelationship(jobID: job.id)
                )
            }
            result.append(payRate)
        }
        return result
    }

    private static func makeDefaultWorkType(
        for job: JobEntity,
        basePayKind: String,
        in context: NSManagedObjectContext
    ) throws(LegacyWorkTypeBackfillError) -> WorkTypeEntity {
        guard let entityDescription = NSEntityDescription.entity(
            forEntityName: "WorkTypeEntity",
            in: context
        ) else {
            throw .missingWorkTypeEntityDescription
        }

        let workType = WorkTypeEntity(entity: entityDescription, insertInto: context)
        workType.id = job.id
        workType.basePayKind = basePayKind
        workType.job = job
        return workType
    }

    private static func uuidPrecedes(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
