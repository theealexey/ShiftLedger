import CoreData
import Foundation

enum ShiftStorageError: Error {
    enum Corruption: Error {
        case invalidWorkTypesRelationship
        case missingWorkType
        case duplicateWorkTypeIdentity(workTypeID: UUID)
        case workTypeBelongsToDifferentJob(
            workTypeID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case missingShiftWorkType(shiftID: UUID)
        case shiftWorkTypeBelongsToDifferentJob(
            shiftID: UUID,
            workTypeID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case missingShiftJobRelationship(shiftID: UUID)
        case shiftJobBelongsToDifferentJob(
            shiftID: UUID,
            expectedJobID: UUID,
            actualJobID: UUID
        )
        case invalidBreakPair
        case invalidShift(underlying: ShiftValidationError)
    }

    case jobNotFound
    case multipleJobsFound
    case workTypeNotFound(workTypeID: UUID)
    case duplicateShift
    case overlappingShift
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case corruptedData(Corruption)
}

private enum ShiftManagedObjectCreationError: Error {
    case missingShiftEntityDescription
}

@MainActor
final class ShiftStorage {
    private let context: NSManagedObjectContext

    init(stack: CoreDataStack) {
        context = stack.viewContext
    }

    func save(_ shift: Shift) throws {
        let job = try singleJob()
        let workTypes = try workTypes(for: job)
        let workType = try workType(id: shift.workTypeID, in: workTypes)
        let existingShifts = try fetchShifts()

        for entity in existingShifts {
            let existingShift = try makeShift(from: entity, job: job)

            if entity.id == shift.id {
                throw ShiftStorageError.duplicateShift
            }

            if existingShift.overlaps(with: shift) {
                throw ShiftStorageError.overlappingShift
            }
        }

        guard let entityDescription = NSEntityDescription.entity(
            forEntityName: "ShiftEntity",
            in: context
        ) else {
            throw ShiftStorageError.saveFailed(
                underlying: ShiftManagedObjectCreationError.missingShiftEntityDescription
            )
        }

        let entity = ShiftEntity(entity: entityDescription, insertInto: context)
        entity.id = shift.id
        entity.start = shift.start
        entity.end = shift.end
        entity.unpaidBreakStart = shift.unpaidBreak?.start
        entity.unpaidBreakEnd = shift.unpaidBreak?.end
        entity.workType = workType
        entity.job = job

        do {
            try context.save()
        } catch {
            context.rollback()
            throw ShiftStorageError.saveFailed(underlying: error)
        }
    }

    func loadAll() throws -> [Shift] {
        let job = try singleJob()
        _ = try workTypes(for: job)

        return try fetchShifts().map { entity in
            try makeShift(from: entity, job: job)
        }
        .sorted {
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            if $0.end != $1.end {
                return $0.end < $1.end
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func singleJob() throws -> JobEntity {
        let request = NSFetchRequest<JobEntity>(entityName: "JobEntity")
        request.fetchLimit = 2

        let jobs: [JobEntity]
        do {
            jobs = try context.fetch(request)
        } catch {
            throw ShiftStorageError.fetchFailed(underlying: error)
        }

        switch jobs.count {
        case 0:
            throw ShiftStorageError.jobNotFound
        case 1:
            return jobs[0]
        default:
            throw ShiftStorageError.multipleJobsFound
        }
    }

    private func fetchShifts() throws -> [ShiftEntity] {
        let request = NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity")
        do {
            return try context.fetch(request)
        } catch {
            throw ShiftStorageError.fetchFailed(underlying: error)
        }
    }

    private func workTypes(for job: JobEntity) throws -> [WorkTypeEntity] {
        var workTypes: [WorkTypeEntity] = []
        for object in job.workTypes ?? NSSet() {
            guard let workType = object as? WorkTypeEntity else {
                throw ShiftStorageError.corruptedData(.invalidWorkTypesRelationship)
            }
            workTypes.append(workType)
        }

        guard workTypes.isEmpty == false else {
            throw ShiftStorageError.corruptedData(.missingWorkType)
        }

        let sortedWorkTypes = workTypes.sorted(by: isWorkTypeOrderedBefore)
        var workTypeIDs = Set<UUID>()
        for workType in sortedWorkTypes {
            guard workType.job.objectID == job.objectID else {
                throw ShiftStorageError.corruptedData(
                    .workTypeBelongsToDifferentJob(
                        workTypeID: workType.id,
                        expectedJobID: job.id,
                        actualJobID: workType.job.id
                    )
                )
            }
            guard workTypeIDs.insert(workType.id).inserted else {
                throw ShiftStorageError.corruptedData(
                    .duplicateWorkTypeIdentity(workTypeID: workType.id)
                )
            }
        }

        return sortedWorkTypes
    }

    private func workType(
        id: UUID,
        in workTypes: [WorkTypeEntity]
    ) throws -> WorkTypeEntity {
        for workType in workTypes where workType.id == id {
            return workType
        }
        throw ShiftStorageError.workTypeNotFound(workTypeID: id)
    }

    private func isWorkTypeOrderedBefore(
        _ lhs: WorkTypeEntity,
        _ rhs: WorkTypeEntity
    ) -> Bool {
        if lhs.id != rhs.id {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.objectID.uriRepresentation().absoluteString
            < rhs.objectID.uriRepresentation().absoluteString
    }

    private func validatedWorkType(
        of shift: ShiftEntity,
        job: JobEntity
    ) throws -> WorkTypeEntity {
        guard let shiftJob = shift.job else {
            throw ShiftStorageError.corruptedData(
                .missingShiftJobRelationship(shiftID: shift.id)
            )
        }
        guard shiftJob.objectID == job.objectID else {
            throw ShiftStorageError.corruptedData(
                .shiftJobBelongsToDifferentJob(
                    shiftID: shift.id,
                    expectedJobID: job.id,
                    actualJobID: shiftJob.id
                )
            )
        }
        guard let shiftWorkType = shift.workType else {
            throw ShiftStorageError.corruptedData(
                .missingShiftWorkType(shiftID: shift.id)
            )
        }
        guard shiftWorkType.job.objectID == job.objectID else {
            throw ShiftStorageError.corruptedData(
                .shiftWorkTypeBelongsToDifferentJob(
                    shiftID: shift.id,
                    workTypeID: shiftWorkType.id,
                    expectedJobID: job.id,
                    actualJobID: shiftWorkType.job.id
                )
            )
        }

        return shiftWorkType
    }

    private func makeShift(from entity: ShiftEntity, job: JobEntity) throws -> Shift {
        let workType = try validatedWorkType(of: entity, job: job)
        let unpaidBreak: UnpaidBreak?

        switch (entity.unpaidBreakStart, entity.unpaidBreakEnd) {
        case (nil, nil):
            unpaidBreak = nil
        case let (start?, end?):
            unpaidBreak = UnpaidBreak(start: start, end: end)
        default:
            throw ShiftStorageError.corruptedData(.invalidBreakPair)
        }

        do {
            return try Shift(
                id: entity.id,
                workTypeID: workType.id,
                start: entity.start,
                end: entity.end,
                unpaidBreak: unpaidBreak
            )
        } catch {
            throw ShiftStorageError.corruptedData(.invalidShift(underlying: error))
        }
    }
}
