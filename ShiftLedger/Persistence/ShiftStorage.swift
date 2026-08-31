import CoreData
import Foundation

enum ShiftStorageError: Error {
    enum Corruption: Error {
        case invalidShiftRelationship
        case invalidBreakPair
        case invalidShift(underlying: Error)
    }

    case jobNotFound
    case multipleJobsFound
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
        let existingShifts = try fetchShifts()

        for entity in existingShifts {
            guard let entityJob = entity.value(forKey: "job") as? JobEntity else {
                throw ShiftStorageError.corruptedData(.invalidShiftRelationship)
            }

            guard entityJob.objectID == job.objectID else {
                continue
            }

            if entity.id == shift.id {
                throw ShiftStorageError.duplicateShift
            }

            let existingShift = try makeShift(from: entity)
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

        return try fetchShifts().map { entity in
            guard let entityJob = entity.value(forKey: "job") as? JobEntity,
                  entityJob.objectID == job.objectID
            else {
                throw ShiftStorageError.corruptedData(.invalidShiftRelationship)
            }

            return try makeShift(from: entity)
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

    private func makeShift(from entity: ShiftEntity) throws -> Shift {
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
                start: entity.start,
                end: entity.end,
                unpaidBreak: unpaidBreak
            )
        } catch {
            throw ShiftStorageError.corruptedData(.invalidShift(underlying: error))
        }
    }
}
