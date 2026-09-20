import CoreData
import Foundation

enum LegacyShiftWorkTypeBackfillError: Error {
    enum InvariantViolation: Error, Equatable {
        case missingJobRelationship(shiftID: UUID)
        case duplicateJobIdentity(UUID)
        case missingDefaultWorkType(shiftID: UUID, jobID: UUID)
        case duplicateDefaultWorkTypeIdentity(jobID: UUID)
        case defaultWorkTypeBelongsToDifferentJob(jobID: UUID, actualJobID: UUID)
        case shiftWorkTypeBelongsToDifferentJob(
            shiftID: UUID,
            workTypeID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
    }

    case fetchFailed(underlying: Error)
    case invariantViolation(InvariantViolation)
    case saveFailed(underlying: Error)
}

@MainActor
enum LegacyShiftWorkTypeBackfill {
    static func run(
        in context: NSManagedObjectContext
    ) throws(LegacyShiftWorkTypeBackfillError) {
        do {
            try execute(in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func execute(
        in context: NSManagedObjectContext
    ) throws(LegacyShiftWorkTypeBackfillError) {
        let jobs: [JobEntity]
        let workTypes: [WorkTypeEntity]
        let shifts: [ShiftEntity]

        do {
            jobs = try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
            workTypes = try context.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            )
            shifts = try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
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

        let workTypesByID = Dictionary(grouping: workTypes, by: \.id)
        let sortedShifts = shifts.sorted { uuidPrecedes($0.id, $1.id) }

        for shift in sortedShifts {
            guard let job = shift.job else {
                throw .invariantViolation(.missingJobRelationship(shiftID: shift.id))
            }

            if let existingWorkType = shift.workType {
                guard existingWorkType.job.objectID == job.objectID else {
                    throw .invariantViolation(
                        .shiftWorkTypeBelongsToDifferentJob(
                            shiftID: shift.id,
                            workTypeID: existingWorkType.id,
                            expectedJobID: job.id,
                            actualJobID: existingWorkType.job.id
                        )
                    )
                }
                continue
            }

            let matchingWorkTypes = workTypesByID[job.id, default: []]
            guard !matchingWorkTypes.isEmpty else {
                throw .invariantViolation(
                    .missingDefaultWorkType(shiftID: shift.id, jobID: job.id)
                )
            }
            guard matchingWorkTypes.count == 1 else {
                throw .invariantViolation(
                    .duplicateDefaultWorkTypeIdentity(jobID: job.id)
                )
            }

            let defaultWorkType = matchingWorkTypes[0]
            guard defaultWorkType.job.objectID == job.objectID else {
                throw .invariantViolation(
                    .defaultWorkTypeBelongsToDifferentJob(
                        jobID: job.id,
                        actualJobID: defaultWorkType.job.id
                    )
                )
            }

            shift.workType = defaultWorkType
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

    private static func uuidPrecedes(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
