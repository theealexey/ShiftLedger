import CoreData
import Foundation

enum ShiftStorageError: Error {
    enum Corruption: Error {
        case invalidWorkTypesRelationship
        case missingWorkType
        case duplicateWorkTypeIdentity(workTypeID: UUID)
        case duplicateShiftIdentity(shiftID: UUID)
        case duplicateJobIdentity(jobID: UUID)
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

    case jobNotFound(jobID: UUID)
    case jobArchived(jobID: UUID)
    case foreignShiftOwner(shiftID: UUID, expectedJobID: UUID, actualJobID: UUID)
    case workTypeNotFound(workTypeID: UUID)
    case workTypeArchived(workTypeID: UUID)
    case shiftNotFound(shiftID: UUID)
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

    func save(_ shift: Shift, forJobID jobID: UUID) throws {
        let job = try job(id: jobID)
        try validateOwner(of: shift, job: job)
        try validateWritable(job)
        let matches = try fetchShifts(matching: NSPredicate(format: "id == %@", shift.id as NSUUID))
        guard matches.count <= 1 else {
            throw ShiftStorageError.corruptedData(.duplicateShiftIdentity(shiftID: shift.id))
        }
        guard matches.isEmpty else { throw ShiftStorageError.duplicateShift }
        let workTypes = try workTypes(for: job)
        let workType = try workType(id: shift.workTypeID, in: workTypes)
        try validateNewAssignment(to: workType)
        let existingShifts = try history(for: job)

        for entity in existingShifts {
            let existingShift = try makeShift(from: entity, job: job)

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

    func update(_ shift: Shift, forJobID jobID: UUID) throws {
        let job = try job(id: jobID)
        try validateOwner(of: shift, job: job)
        try validateWritable(job)
        let workTypes = try workTypes(for: job)
        let target = try uniqueShift(id: shift.id, for: job)
        let existingShifts = try history(for: job)
        let requestedWorkType = try workType(id: shift.workTypeID, in: workTypes)
        let existingWorkType = try validatedWorkType(of: target, job: job)
        if requestedWorkType.objectID != existingWorkType.objectID {
            try validateNewAssignment(to: requestedWorkType)
        }

        for entity in existingShifts {
            let existingShift = try makeShift(from: entity, job: job)

            guard entity.objectID != target.objectID else {
                continue
            }

            if existingShift.overlaps(with: shift) {
                throw ShiftStorageError.overlappingShift
            }
        }

        target.start = shift.start
        target.end = shift.end
        target.unpaidBreakStart = shift.unpaidBreak?.start
        target.unpaidBreakEnd = shift.unpaidBreak?.end
        target.workType = requestedWorkType

        do {
            try context.save()
        } catch {
            context.rollback()
            throw ShiftStorageError.saveFailed(underlying: error)
        }
    }

    func delete(id shiftID: UUID, inJobID jobID: UUID) throws {
        let job = try job(id: jobID)
        try validateWritable(job)
        _ = try workTypes(for: job)
        let target = try uniqueShift(id: shiftID, for: job)
        _ = try validatedWorkType(of: target, job: job)

        context.delete(target)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw ShiftStorageError.saveFailed(underlying: error)
        }
    }

    func loadAll(forJobID jobID: UUID) throws -> [Shift] {
        let job = try job(id: jobID)
        _ = try workTypes(for: job)

        return try history(for: job).map { entity in
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

    private func job(id: UUID) throws -> JobEntity {
        let request = NSFetchRequest<JobEntity>(entityName: "JobEntity")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 2

        let jobs: [JobEntity]
        do {
            jobs = try context.fetch(request)
        } catch {
            throw ShiftStorageError.fetchFailed(underlying: error)
        }

        switch jobs.count {
        case 0:
            throw ShiftStorageError.jobNotFound(jobID: id)
        case 1:
            return jobs[0]
        default:
            throw ShiftStorageError.corruptedData(.duplicateJobIdentity(jobID: id))
        }
    }

    private func validateWritable(_ job: JobEntity) throws {
        guard !job.isArchived else { throw ShiftStorageError.jobArchived(jobID: job.id) }
    }

    private func validateOwner(of shift: Shift, job: JobEntity) throws {
        guard shift.jobID == job.id else {
            throw ShiftStorageError.foreignShiftOwner(
                shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
            )
        }
    }

    private func fetchShifts(matching predicate: NSPredicate) throws -> [ShiftEntity] {
        let request = NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity")
        request.predicate = predicate
        do {
            return try context.fetch(request)
        } catch {
            throw ShiftStorageError.fetchFailed(underlying: error)
        }
    }

    private func history(for job: JobEntity) throws -> [ShiftEntity] {
        // Either relationship associates a record with this Job for validation.
        // A record with neither relationship cannot be attributed safely; report
        // corruption rather than silently returning an incomplete history.
        let shifts = try fetchShifts(matching: NSPredicate(
            format: "job == %@ OR workType.job == %@ OR (job == nil AND workType == nil)",
            job, job
        ))
        guard !shifts.isEmpty else { return [] }

        // Identity is global, while overlap/history is Job-scoped. Only query
        // identities represented in this history, not another Job's history.
        let identities = try fetchShifts(matching: NSPredicate(
            format: "id IN %@", shifts.map { $0.id as NSUUID }
        ))
        var seen = Set<UUID>()
        for entity in identities {
            guard seen.insert(entity.id).inserted else {
                throw ShiftStorageError.corruptedData(.duplicateShiftIdentity(shiftID: entity.id))
            }
        }
        return shifts
    }

    private func uniqueShift(
        id: UUID,
        for job: JobEntity
    ) throws -> ShiftEntity {
        let matches = try fetchShifts(matching: NSPredicate(format: "id == %@", id as NSUUID))

        switch matches.count {
        case 0:
            throw ShiftStorageError.shiftNotFound(shiftID: id)
        case 1:
            if let owner = matches[0].job, owner.objectID != job.objectID {
                throw ShiftStorageError.foreignShiftOwner(
                    shiftID: id, expectedJobID: job.id, actualJobID: owner.id
                )
            }
            return matches[0]
        default:
            throw ShiftStorageError.corruptedData(
                .duplicateShiftIdentity(shiftID: id)
            )
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

    private func validateNewAssignment(to workType: WorkTypeEntity) throws {
        guard workType.isArchived == false else {
            throw ShiftStorageError.workTypeArchived(workTypeID: workType.id)
        }
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
                jobID: job.id,
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
