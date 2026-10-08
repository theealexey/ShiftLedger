import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftStorageTests {
    private let canonicalWorkTypeID = UUID(uuid: (0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let multiJobID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let firstWorkTypeID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let secondWorkTypeID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))

    @Test("Foreign ownership is rejected before save/update mutation and survives SQLite reopen",
          arguments: [false, true])
    func rejectsForeignOwnerWithoutMutation(_ updating: Bool) async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let job = try makeJob()
        try JobStorage(stack: stack).save(job)
        let original = try makeShift(jobID: job.id)
        let storage = ShiftStorage(stack: stack)
        try storage.save(original, forJobID: canonicalWorkTypeID)
        let foreignOwner = testJobID
        let proposed = try Shift(
            id: updating ? original.id : testWorkTypeID,
            jobID: foreignOwner,
            workTypeID: original.workTypeID,
            start: original.start.addingTimeInterval(86_400),
            end: original.end.addingTimeInterval(86_400)
        )
        var rejected = false
        do {
            if updating { try storage.update(proposed, forJobID: canonicalWorkTypeID) }
            else { try storage.save(proposed, forJobID: canonicalWorkTypeID) }
        } catch ShiftStorageError.foreignShiftOwner(let shiftID, let expected, let actual) {
            rejected = true
            #expect(shiftID == proposed.id)
            #expect(expected == job.id)
            #expect(actual == foreignOwner)
        }
        #expect(rejected)
        #expect(stack.viewContext.hasChanges == false)
        #expect(try storage.loadAll(forJobID: canonicalWorkTypeID) == [original])
        #expect(try JobStorage(stack: stack).load() == job)
        try close(stack)
        let reopened = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: canonicalWorkTypeID) == [original])
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: canonicalWorkTypeID).first?.jobID == job.id)
        #expect(try JobStorage(stack: reopened).load() == job)
        #expect(try fetchShifts(in: reopened.viewContext).count == 1)
    }

    @Test("Смена без перерыва переживает SQLite reopen")
    func roundTripsShiftWithoutBreak() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let shift = try makeShift(id: "8A3B3F10-1F62-4E7D-8D25-8BBD5A37DF11", start: 10 * 60 * 60)
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let job = try makeJob()
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(shift, forJobID: job.id)

        #expect(try ShiftStorage(stack: stackA).loadAll(forJobID: canonicalWorkTypeID) == [shift])

        let persistedJobs = try fetchJobs(in: stackA.viewContext)
        let persistedWorkTypes = try fetchWorkTypes(in: stackA.viewContext)
        let persistedShifts = try fetchShifts(in: stackA.viewContext)
        let persistedJob = try #require(persistedJobs.first)
        let persistedWorkType = try #require(persistedWorkTypes.first)
        let persistedShift = try #require(persistedShifts.first)

        #expect(persistedJobs.count == 1)
        #expect(persistedWorkTypes.count == 1)
        #expect(persistedShifts.count == 1)
        #expect(persistedWorkType.id == job.soleWorkType?.id)
        #expect(persistedWorkType.id == persistedJob.id)
        #expect(persistedShift.workType?.objectID == persistedWorkType.objectID)
        #expect(persistedWorkType.shifts?.contains(persistedShift) == true)
        #expect(persistedShift.job?.objectID == persistedJob.objectID)
        #expect(persistedJob.shifts?.contains(persistedShift) == true)
        #expect(persistedShift.id == shift.id)
        #expect(persistedShift.start == shift.start)
        #expect(persistedShift.end == shift.end)
        #expect(persistedShift.unpaidBreakStart == nil)
        #expect(persistedShift.unpaidBreakEnd == nil)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let loaded = try #require(try ShiftStorage(stack: stackB).loadAll(forJobID: canonicalWorkTypeID).first)
        #expect(loaded == shift)
        #expect(loaded.workTypeID == canonicalWorkTypeID)
        #expect(loaded.unpaidBreak == nil)
        #expect(try fetchWorkTypes(in: stackB.viewContext).count == 1)
        #expect(try fetchShifts(in: stackB.viewContext).count == 1)

        let reopenedShift = try #require(try fetchShifts(in: stackB.viewContext).first)
        let reopenedWorkType = try #require(try fetchWorkTypes(in: stackB.viewContext).first)
        #expect(reopenedShift.workType?.objectID == reopenedWorkType.objectID)
        #expect(reopenedShift.job?.id == job.id)
    }

    @Test("Смена с неоплачиваемым перерывом переживает SQLite reopen")
    func roundTripsShiftWithBreak() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let start = Date(timeIntervalSinceReferenceDate: 20_000)
        let shift = try Shift(
            id: try #require(UUID(uuidString: "2E80C3A1-7F3C-4D6C-BDA9-1E62C2A4A1F4")),
            jobID: canonicalWorkTypeID,
            workTypeID: canonicalWorkTypeID,
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(3 * 60 * 60),
                end: start.addingTimeInterval(4 * 60 * 60)
            )
        )
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(try makeJob())
        try ShiftStorage(stack: stackA).save(shift, forJobID: canonicalWorkTypeID)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let loaded = try #require(try ShiftStorage(stack: stackB).loadAll(forJobID: canonicalWorkTypeID).first)
        #expect(loaded.id == shift.id)
        #expect(loaded.workTypeID == canonicalWorkTypeID)
        #expect(loaded.start == shift.start)
        #expect(loaded.end == shift.end)
        #expect(loaded.unpaidBreak == shift.unpaidBreak)
    }

    @Test("Shifts сохраняют точные WorkType assignments после SQLite reopen")
    func roundTripsMultiWorkTypeAssignments() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let job = try makeMultiWorkTypeJob()
        let firstShift = try makeShift(
            id: "72000000-0000-0000-0000-000000000011",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let secondShift = try makeShift(
            id: "72000000-0000-0000-0000-000000000012",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(firstShift, forJobID: multiJobID)
        try ShiftStorage(stack: stackA).save(secondShift, forJobID: multiJobID)

        let persistedJobs = try fetchJobs(in: stackA.viewContext)
        let persistedWorkTypes = try fetchWorkTypes(in: stackA.viewContext)
        let persistedShifts = try fetchShifts(in: stackA.viewContext)
        let persistedJob = try #require(persistedJobs.first)
        let persistedFirstWorkType = try #require(
            persistedWorkTypes.first { $0.id == firstWorkTypeID }
        )
        let persistedSecondWorkType = try #require(
            persistedWorkTypes.first { $0.id == secondWorkTypeID }
        )
        let persistedFirstShift = try #require(
            persistedShifts.first { $0.id == firstShift.id }
        )
        let persistedSecondShift = try #require(
            persistedShifts.first { $0.id == secondShift.id }
        )

        #expect(persistedJobs.count == 1)
        #expect(persistedWorkTypes.count == 2)
        #expect(persistedShifts.count == 2)
        #expect(persistedJob.id == multiJobID)
        #expect(persistedJob.id != persistedFirstWorkType.id)
        #expect(persistedJob.id != persistedSecondWorkType.id)
        #expect(persistedFirstShift.workType?.objectID == persistedFirstWorkType.objectID)
        #expect(persistedSecondShift.workType?.objectID == persistedSecondWorkType.objectID)
        #expect(persistedFirstShift.job?.objectID == persistedJob.objectID)
        #expect(persistedSecondShift.job?.objectID == persistedJob.objectID)
        #expect(persistedFirstWorkType.shifts?.contains(persistedFirstShift) == true)
        #expect(persistedFirstWorkType.shifts?.contains(persistedSecondShift) == false)
        #expect(persistedSecondWorkType.shifts?.contains(persistedSecondShift) == true)
        #expect(persistedSecondWorkType.shifts?.contains(persistedFirstShift) == false)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let loaded = try ShiftStorage(stack: stackB).loadAll(forJobID: multiJobID)

        #expect(loaded == [firstShift, secondShift])
        #expect(loaded.map(\.workTypeID) == [firstWorkTypeID, secondWorkTypeID])
        #expect(try fetchWorkTypes(in: stackB.viewContext).count == 2)
        #expect(try fetchShifts(in: stackB.viewContext).count == 2)
    }

    @Test("New Shift cannot be assigned to an archived WorkType")
    func rejectsNewShiftAssignmentToArchivedWorkType() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let activeJob = try makeJob()
        let archivedJob = try activeJob.archivingWorkType(id: canonicalWorkTypeID)
        try JobStorage(stack: stack).save(archivedJob)

        do {
            try ShiftStorage(stack: stack).save(try makeShift(), forJobID: canonicalWorkTypeID)
            Issue.record("A new Shift was assigned to an archived WorkType")
        } catch ShiftStorageError.workTypeArchived(let workTypeID) {
            #expect(workTypeID == canonicalWorkTypeID)
        }

        #expect(try fetchShifts(in: stack.viewContext).isEmpty)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Existing archived Shift assignment remains editable but cannot move to another archived WorkType")
    func preservesExistingArchivedAssignmentDuringUpdate() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let job = try makeMultiWorkTypeJob()
        try JobStorage(stack: stack).save(job)
        let initial = try makeShift(
            id: "73000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(initial, forJobID: multiJobID)
        let jobStorage = JobStorage(stack: stack)
        _ = try jobStorage.archiveWorkType(id: firstWorkTypeID, inJobID: multiJobID)

        let movedInTime = try Shift(
            id: initial.id,
            jobID: multiJobID,
            workTypeID: firstWorkTypeID,
            start: initial.start.addingTimeInterval(60 * 60),
            end: initial.end.addingTimeInterval(60 * 60)
        )
        try storage.update(movedInTime, forJobID: multiJobID)
        #expect(try storage.loadAll(forJobID: multiJobID) == [movedInTime])

        _ = try jobStorage.archiveWorkType(id: secondWorkTypeID, inJobID: multiJobID)
        let reassigned = try Shift(
            id: initial.id,
            jobID: multiJobID,
            workTypeID: secondWorkTypeID,
            start: movedInTime.start,
            end: movedInTime.end
        )
        do {
            try storage.update(reassigned, forJobID: multiJobID)
            Issue.record("An existing Shift was reassigned to another archived WorkType")
        } catch ShiftStorageError.workTypeArchived(let workTypeID) {
            #expect(workTypeID == secondWorkTypeID)
        }

        #expect(try storage.loadAll(forJobID: multiJobID) == [movedInTime])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Update изменяет Shift in place, сохраняет exact WorkType и переживает reopen")
    func updatesShiftInPlaceAndSurvivesReopen() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(try makeMultiWorkTypeJob())
        let original = try makeShift(
            id: "74000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let unrelated = try makeShift(
            id: "74000000-0000-0000-0000-000000000002",
            start: 50 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stackA)
        try storage.save(original, forJobID: multiJobID)
        try storage.save(unrelated, forJobID: multiJobID)

        let beforeShifts = try fetchShifts(in: stackA.viewContext)
        let targetBefore = try #require(beforeShifts.first { $0.id == original.id })
        let unrelatedBefore = try #require(beforeShifts.first { $0.id == unrelated.id })
        let targetObjectID = targetBefore.objectID
        let unrelatedObjectID = unrelatedBefore.objectID
        let workTypesBefore = try fetchWorkTypes(in: stackA.viewContext)
        let firstWorkTypeObjectID = try #require(
            workTypesBefore.first { $0.id == firstWorkTypeID }
        ).objectID
        let secondWorkTypeObjectID = try #require(
            workTypesBefore.first { $0.id == secondWorkTypeID }
        ).objectID

        let updatedStart = Date(timeIntervalSinceReferenceDate: 25 * 60 * 60)
        let updated = try Shift(
            id: original.id,
            jobID: multiJobID,
            workTypeID: secondWorkTypeID,
            start: updatedStart,
            end: updatedStart.addingTimeInterval(10 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: updatedStart.addingTimeInterval(4 * 60 * 60),
                end: updatedStart.addingTimeInterval(5 * 60 * 60)
            )
        )

        try storage.update(updated, forJobID: multiJobID)

        let afterShifts = try fetchShifts(in: stackA.viewContext)
        let workTypesAfter = try fetchWorkTypes(in: stackA.viewContext)
        let targetAfter = try #require(afterShifts.first { $0.id == updated.id })
        let unrelatedAfter = try #require(afterShifts.first { $0.id == unrelated.id })
        let persistedJob = try #require(try fetchJobs(in: stackA.viewContext).first)
        #expect(afterShifts.count == 2)
        #expect(targetAfter.objectID == targetObjectID)
        #expect(unrelatedAfter.objectID == unrelatedObjectID)
        #expect(targetAfter.workType?.objectID == secondWorkTypeObjectID)
        #expect(targetAfter.job?.objectID == persistedJob.objectID)
        #expect(targetAfter.start == updated.start)
        #expect(targetAfter.end == updated.end)
        #expect(targetAfter.unpaidBreakStart == updated.unpaidBreak?.start)
        #expect(targetAfter.unpaidBreakEnd == updated.unpaidBreak?.end)
        #expect(unrelatedAfter.workType?.objectID == firstWorkTypeObjectID)
        #expect(workTypesAfter.count == 2)
        #expect(workTypesAfter.map(\.objectID).contains(firstWorkTypeObjectID))
        #expect(workTypesAfter.map(\.objectID).contains(secondWorkTypeObjectID))
        #expect(try storage.loadAll(forJobID: multiJobID) == [updated, unrelated])
        #expect(stackA.viewContext.hasChanges == false)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: stackB).loadAll(forJobID: multiJobID) == [updated, unrelated])
        #expect(try fetchShifts(in: stackB.viewContext).count == 2)
    }

    @Test("Update без изменений не считает Shift пересечением с собой")
    func unchangedUpdatePreservesObjectIdentity() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let shift = try makeShift(id: "75000000-0000-0000-0000-000000000001")
        let storage = ShiftStorage(stack: stack)
        try storage.save(shift, forJobID: canonicalWorkTypeID)
        let objectID = try #require(try fetchShifts(in: stack.viewContext).first).objectID

        try storage.update(shift, forJobID: canonicalWorkTypeID)

        let persisted = try fetchShifts(in: stack.viewContext)
        #expect(persisted.count == 1)
        #expect(persisted.first?.objectID == objectID)
        #expect(try storage.loadAll(forJobID: canonicalWorkTypeID) == [shift])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Update отклоняет Job-wide overlap между разными WorkTypes без мутации target")
    func updateRejectsCrossWorkTypeOverlapWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeMultiWorkTypeJob())
        let target = try makeShift(
            id: "76000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let other = try makeShift(
            id: "76000000-0000-0000-0000-000000000002",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target, forJobID: multiJobID)
        try storage.save(other, forJobID: multiJobID)
        let targetObjectID = try #require(
            try fetchShifts(in: stack.viewContext).first { $0.id == target.id }
        ).objectID
        let proposedStart = Date(timeIntervalSinceReferenceDate: 19 * 60 * 60)
        let proposed = try Shift(
            id: target.id,
            jobID: multiJobID,
            workTypeID: firstWorkTypeID,
            start: proposedStart,
            end: proposedStart.addingTimeInterval(2 * 60 * 60)
        )

        do {
            try storage.update(proposed, forJobID: multiJobID)
            Issue.record("Пересекающийся update был сохранён")
        } catch ShiftStorageError.overlappingShift {
        }

        let persistedTarget = try #require(
            try fetchShifts(in: stack.viewContext).first { $0.id == target.id }
        )
        #expect(persistedTarget.objectID == targetObjectID)
        #expect(try storage.loadAll(forJobID: multiJobID) == [target, other])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Update разрешает adjacency к Shift другого WorkType")
    func updateAllowsAdjacencyAcrossWorkTypes() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeMultiWorkTypeJob())
        let target = try makeShift(
            id: "77000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let other = try makeShift(
            id: "77000000-0000-0000-0000-000000000002",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target, forJobID: multiJobID)
        try storage.save(other, forJobID: multiJobID)
        let adjacentStart = Date(timeIntervalSinceReferenceDate: 12 * 60 * 60)
        let adjacent = try Shift(
            id: target.id,
            jobID: multiJobID,
            workTypeID: firstWorkTypeID,
            start: adjacentStart,
            end: other.start
        )

        try storage.update(adjacent, forJobID: multiJobID)

        #expect(try storage.loadAll(forJobID: multiJobID) == [adjacent, other])
    }

    @Test("Update с неизвестным WorkType отклоняется без изменения target")
    func updateRejectsUnknownWorkTypeWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeMultiWorkTypeJob())
        let target = try makeShift(
            id: "78000000-0000-0000-0000-000000000001",
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target, forJobID: multiJobID)
        let unknownID = UUID(uuid: (0x78, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
        let proposed = try Shift(
            id: target.id,
            jobID: target.jobID,
            workTypeID: unknownID,
            start: target.start.addingTimeInterval(60),
            end: target.end.addingTimeInterval(60)
        )

        do {
            try storage.update(proposed, forJobID: multiJobID)
            Issue.record("Update с неизвестным WorkType был сохранён")
        } catch ShiftStorageError.workTypeNotFound(let workTypeID) {
            #expect(workTypeID == unknownID)
        }

        #expect(try storage.loadAll(forJobID: multiJobID) == [target])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Update отсутствующего Shift возвращает точный shiftNotFound")
    func updateRejectsMissingShiftWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let existing = try makeShift(id: "79000000-0000-0000-0000-000000000001")
        let storage = ShiftStorage(stack: stack)
        try storage.save(existing, forJobID: canonicalWorkTypeID)
        let missing = try makeShift(id: "79000000-0000-0000-0000-000000000002")

        do {
            try storage.update(missing, forJobID: canonicalWorkTypeID)
            Issue.record("Отсутствующий Shift был обновлён")
        } catch ShiftStorageError.shiftNotFound(let shiftID) {
            #expect(shiftID == missing.id)
        }

        #expect(try storage.loadAll(forJobID: canonicalWorkTypeID) == [existing])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Duplicate persisted Shift ID отклоняется как corruption без выбора target")
    func updateRejectsDuplicatePersistedShiftIdentity() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let workType = try onlyWorkType(for: job)
        let duplicateID = UUID(uuid: (0x7A, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let first = try insertShiftEntity(
            id: duplicateID,
            job: job,
            workType: workType,
            start: Date(timeIntervalSinceReferenceDate: 10 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 18 * 60 * 60),
            in: stack.viewContext
        )
        let second = try insertShiftEntity(
            id: duplicateID,
            job: job,
            workType: workType,
            start: Date(timeIntervalSinceReferenceDate: 30 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 38 * 60 * 60),
            in: stack.viewContext
        )
        try stack.viewContext.save()
        let firstStart = first.start
        let secondStart = second.start
        let proposed = try Shift(
            id: duplicateID,
            jobID: canonicalWorkTypeID,
            workTypeID: canonicalWorkTypeID,
            start: Date(timeIntervalSinceReferenceDate: 50 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 58 * 60 * 60)
        )

        do {
            try ShiftStorage(stack: stack).update(proposed, forJobID: canonicalWorkTypeID)
            Issue.record("Один из duplicate Shift был произвольно обновлён")
        } catch ShiftStorageError.corruptedData(
            .duplicateShiftIdentity(let shiftID)
        ) {
            #expect(shiftID == duplicateID)
        }

        #expect(first.start == firstStart)
        #expect(second.start == secondStart)
        #expect(try fetchShifts(in: stack.viewContext).count == 2)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Update не исправляет target с отсутствующим WorkType")
    func updateRejectsCorruptedTargetWithoutRepair() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let targetID = UUID(uuid: (0x7B, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let target = try insertShiftEntity(
            id: targetID,
            job: job,
            workType: nil,
            start: Date(timeIntervalSinceReferenceDate: 10 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 18 * 60 * 60),
            in: stack.viewContext
        )
        try stack.viewContext.save()
        let originalStart = target.start
        let proposed = try Shift(
            id: targetID,
            jobID: canonicalWorkTypeID,
            workTypeID: canonicalWorkTypeID,
            start: Date(timeIntervalSinceReferenceDate: 20 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 28 * 60 * 60)
        )

        do {
            try ShiftStorage(stack: stack).update(proposed, forJobID: canonicalWorkTypeID)
            Issue.record("Повреждённый target был молча исправлен")
        } catch ShiftStorageError.corruptedData(
            .missingShiftWorkType(let shiftID)
        ) {
            #expect(shiftID == targetID)
        }

        #expect(target.start == originalStart)
        #expect(target.workType == nil)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete removes only the exact Shift and preserves the persisted graph")
    func deleteRemovesOnlyExactShiftAndPreservesGraph() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let jobStorage = JobStorage(stack: stack)
        try jobStorage.save(try makeMultiWorkTypeJob())
        let target = try makeShift(
            id: "7C000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let unrelated = try makeShift(
            id: "7C000000-0000-0000-0000-000000000002",
            start: 30 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target, forJobID: multiJobID)
        try storage.save(unrelated, forJobID: multiJobID)

        let jobBefore = try #require(try jobStorage.load())
        let jobEntityBefore = try #require(try fetchOnlyJob(in: stack.viewContext))
        let jobObjectID = jobEntityBefore.objectID
        let workTypeObjectIDs = Dictionary(
            uniqueKeysWithValues: try fetchWorkTypes(in: stack.viewContext).map { ($0.id, $0.objectID) }
        )
        let payRateObjectIDs = Set(try fetchPayRates(in: stack.viewContext).map(\.objectID))
        let shiftsBefore = try fetchShifts(in: stack.viewContext)
        let targetObjectID = try #require(shiftsBefore.first { $0.id == target.id }).objectID
        let unrelatedObjectID = try #require(shiftsBefore.first { $0.id == unrelated.id }).objectID

        try storage.delete(id: target.id, inJobID: multiJobID)

        let shiftsAfter = try fetchShifts(in: stack.viewContext)
        let persistedJob = try #require(try fetchOnlyJob(in: stack.viewContext))
        let persistedUnrelated = try #require(shiftsAfter.first { $0.id == unrelated.id })
        let persistedWorkTypes = try fetchWorkTypes(in: stack.viewContext)
        let targetWorkType = try #require(
            persistedWorkTypes.first { $0.id == firstWorkTypeID }
        )
        let unrelatedWorkType = try #require(
            persistedWorkTypes.first { $0.id == secondWorkTypeID }
        )
        let targetWorkTypeShiftObjectIDs = Set(
            (targetWorkType.shifts ?? NSSet()).compactMap { ($0 as? ShiftEntity)?.objectID }
        )
        let unrelatedWorkTypeShiftObjectIDs = Set(
            (unrelatedWorkType.shifts ?? NSSet()).compactMap { ($0 as? ShiftEntity)?.objectID }
        )
        #expect(shiftsAfter.count == 1)
        #expect(shiftsAfter.contains { $0.objectID == targetObjectID } == false)
        #expect(persistedUnrelated.objectID == unrelatedObjectID)
        #expect(persistedUnrelated.job?.objectID == jobObjectID)
        #expect(persistedUnrelated.workType?.objectID == workTypeObjectIDs[secondWorkTypeID])
        #expect(persistedJob.objectID == jobObjectID)
        #expect(persistedJob.shifts?.count == 1)
        #expect(persistedJob.shifts?.contains(persistedUnrelated) == true)
        #expect(targetWorkType.objectID == workTypeObjectIDs[firstWorkTypeID])
        #expect(targetWorkType.shifts?.count == 0)
        #expect(targetWorkTypeShiftObjectIDs.contains(targetObjectID) == false)
        #expect(unrelatedWorkType.objectID == workTypeObjectIDs[secondWorkTypeID])
        #expect(unrelatedWorkType.shifts?.contains(persistedUnrelated) == true)
        #expect(unrelatedWorkTypeShiftObjectIDs.contains(targetObjectID) == false)
        #expect(
            Dictionary(
                uniqueKeysWithValues: persistedWorkTypes.map { ($0.id, $0.objectID) }
            ) == workTypeObjectIDs
        )
        #expect(Set(try fetchPayRates(in: stack.viewContext).map(\.objectID)) == payRateObjectIDs)
        #expect(try jobStorage.load() == jobBefore)
        #expect(try storage.loadAll(forJobID: multiJobID) == [unrelated])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Deleted Shift remains absent after SQLite close and reopen")
    func deleteSurvivesSQLiteReopen() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let job = try makeMultiWorkTypeJob()
        try JobStorage(stack: stackA).save(job)
        let target = try makeShift(
            id: "7D000000-0000-0000-0000-000000000001",
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let remaining = try makeShift(
            id: "7D000000-0000-0000-0000-000000000002",
            start: 30 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stackA)
        try storage.save(target, forJobID: multiJobID)
        try storage.save(remaining, forJobID: multiJobID)
        try storage.delete(id: target.id, inJobID: multiJobID)
        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: stackB).loadAll(forJobID: multiJobID) == [remaining])
        #expect(try JobStorage(stack: stackB).load() == job)
        #expect(try fetchShifts(in: stackB.viewContext).count == 1)
        #expect(try fetchWorkTypes(in: stackB.viewContext).count == 2)
        #expect(try fetchPayRates(in: stackB.viewContext).count == 2)
        #expect(stackB.viewContext.hasChanges == false)
    }

    @Test("Delete accepts a Shift assigned to an archived WorkType")
    func deleteAcceptsArchivedWorkTypeAssignment() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let jobStorage = JobStorage(stack: stack)
        try jobStorage.save(try makeMultiWorkTypeJob())
        let target = try makeShift(
            id: "7E000000-0000-0000-0000-000000000001",
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target, forJobID: multiJobID)
        let archivedJob = try jobStorage.archiveWorkType(id: firstWorkTypeID, inJobID: multiJobID)
        let workTypeObjectIDs = Set(try fetchWorkTypes(in: stack.viewContext).map(\.objectID))
        let payRateObjectIDs = Set(try fetchPayRates(in: stack.viewContext).map(\.objectID))

        try storage.delete(id: target.id, inJobID: multiJobID)

        #expect(try storage.loadAll(forJobID: multiJobID).isEmpty)
        #expect(try jobStorage.load() == archivedJob)
        #expect(Set(try fetchWorkTypes(in: stack.viewContext).map(\.objectID)) == workTypeObjectIDs)
        #expect(Set(try fetchPayRates(in: stack.viewContext).map(\.objectID)) == payRateObjectIDs)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete of an unknown Shift returns exact shiftNotFound without mutation")
    func deleteRejectsUnknownShiftWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let existing = try makeShift(id: "7F000000-0000-0000-0000-000000000001")
        let missingID = UUID(uuid: (0x7F, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        let storage = ShiftStorage(stack: stack)
        try storage.save(existing, forJobID: canonicalWorkTypeID)
        let objectID = try #require(try fetchShifts(in: stack.viewContext).first).objectID

        do {
            try storage.delete(id: missingID, inJobID: canonicalWorkTypeID)
            Issue.record("An unknown Shift was deleted")
        } catch ShiftStorageError.shiftNotFound(let shiftID) {
            #expect(shiftID == missingID)
        }

        #expect(try fetchShifts(in: stack.viewContext).first?.objectID == objectID)
        #expect(try storage.loadAll(forJobID: canonicalWorkTypeID) == [existing])
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete rejects duplicate persisted Shift identity without choosing a target")
    func deleteRejectsDuplicateShiftIdentity() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let workType = try onlyWorkType(for: job)
        let duplicateID = UUID(uuid: (0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let first = try insertShiftEntity(
            id: duplicateID,
            job: job,
            workType: workType,
            start: Date(timeIntervalSinceReferenceDate: 10 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 18 * 60 * 60),
            in: stack.viewContext
        )
        let second = try insertShiftEntity(
            id: duplicateID,
            job: job,
            workType: workType,
            start: Date(timeIntervalSinceReferenceDate: 30 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 38 * 60 * 60),
            in: stack.viewContext
        )
        try stack.viewContext.save()
        let objectIDs = Set([first.objectID, second.objectID])

        do {
            try ShiftStorage(stack: stack).delete(id: duplicateID, inJobID: canonicalWorkTypeID)
            Issue.record("One duplicate Shift was arbitrarily deleted")
        } catch ShiftStorageError.corruptedData(.duplicateShiftIdentity(let shiftID)) {
            #expect(shiftID == duplicateID)
        }

        #expect(Set(try fetchShifts(in: stack.viewContext).map(\.objectID)) == objectIDs)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete without a Job returns exact jobNotFound")
    func deleteRejectsEmptyStore() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)

        do {
            try ShiftStorage(stack: stack).delete(id: UUID(), inJobID: canonicalWorkTypeID)
            Issue.record("Delete succeeded without a Job")
        } catch ShiftStorageError.jobNotFound {
        }

        #expect(try fetchShifts(in: stack.viewContext).isEmpty)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete resolves the requested Job even when another Job exists")
    func deleteRejectsMultipleJobs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(
            id: UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            in: stack.viewContext
        )
        _ = try insertPersistedJob(
            id: UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            try ShiftStorage(stack: stack).delete(
                id: UUID(),
                inJobID: UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
            )
            Issue.record("Delete succeeded for an unknown Shift")
        } catch ShiftStorageError.shiftNotFound {
        }

        #expect(try fetchJobs(in: stack.viewContext).count == 2)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Delete rejects a corrupted target relationship without mutation")
    func deleteRejectsCorruptedTargetWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let targetID = UUID(uuid: (0x82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let target = try insertShiftEntity(
            id: targetID,
            job: job,
            workType: nil,
            start: Date(timeIntervalSinceReferenceDate: 10 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 18 * 60 * 60),
            in: stack.viewContext
        )
        try stack.viewContext.save()
        let objectID = target.objectID

        do {
            try ShiftStorage(stack: stack).delete(id: targetID, inJobID: canonicalWorkTypeID)
            Issue.record("A corrupted Shift was deleted")
        } catch ShiftStorageError.corruptedData(.missingShiftWorkType(let shiftID)) {
            #expect(shiftID == targetID)
        }

        #expect(try fetchShifts(in: stack.viewContext).first?.objectID == objectID)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Sole WorkType с произвольной identity сохраняет Shift assignment")
    func roundTripsSoleArbitraryWorkTypeAssignment() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = try #require(UUID(uuidString: "73000000-0000-0000-0000-000000000001"))
        let workTypeID = try #require(UUID(uuidString: "73000000-0000-0000-0000-000000000002"))
        let payRateID = try #require(UUID(uuidString: "73000000-0000-0000-0000-000000000003"))
        let workType = WorkType(
            id: workTypeID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)]
            )
        )
        let job = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType],
            createdAt: Date(timeIntervalSinceReferenceDate: 10)
        )
        let shift = try makeShift(
            id: "73000000-0000-0000-0000-000000000004",
            workTypeID: workTypeID, jobID: job.id
        )
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(shift, forJobID: job.id)

        let persistedShift = try #require(try fetchShifts(in: stackA.viewContext).first)
        #expect(persistedShift.workType?.id == workTypeID)
        #expect(persistedShift.workType?.id != jobID)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: stackB).loadAll(forJobID: job.id) == [shift])
        #expect(try fetchWorkTypes(in: stackB.viewContext).count == 1)
    }

    @Test("loadAll сортирует по start, end и UUID")
    func sortsDeterministically() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let first = try makeShift(id: "00000000-0000-0000-0000-000000000002", start: 20 * 60 * 60)
        let second = try makeShift(id: "00000000-0000-0000-0000-000000000001", start: 10 * 60 * 60)
        try ShiftStorage(stack: stack).save(first, forJobID: canonicalWorkTypeID)
        try ShiftStorage(stack: stack).save(second, forJobID: canonicalWorkTypeID)

        #expect(try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID) == [second, first])
    }

    @Test("Overlap остаётся Job-wide между разными WorkTypes")
    func enforcesInsertAndOverlapRules() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeMultiWorkTypeJob())
        let first = try makeShift(
            id: "A0000000-0000-0000-0000-000000000001",
            start: 10 * 60 * 60,
            workTypeID: firstWorkTypeID, jobID: multiJobID
        )
        try ShiftStorage(stack: stack).save(first, forJobID: multiJobID)

        do {
            try ShiftStorage(stack: stack).save(first, forJobID: multiJobID)
            Issue.record("Дубликат Shift UUID был сохранён")
        } catch ShiftStorageError.duplicateShift {
        }

        let adjacent = try makeShift(
            id: "A0000000-0000-0000-0000-000000000002",
            start: 18 * 60 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        try ShiftStorage(stack: stack).save(adjacent, forJobID: multiJobID)

        let overlapping = try makeShift(
            id: "A0000000-0000-0000-0000-000000000003",
            start: 17 * 60 * 60 + 59 * 60,
            workTypeID: secondWorkTypeID, jobID: multiJobID
        )
        do {
            try ShiftStorage(stack: stack).save(overlapping, forJobID: multiJobID)
            Issue.record("Пересекающаяся Shift была сохранена")
        } catch ShiftStorageError.overlappingShift {
        }

        #expect(try ShiftStorage(stack: stack).loadAll(forJobID: multiJobID) == [first, adjacent])
    }

    @Test("Без Job сохранение отклоняется typed jobNotFound")
    func rejectsSaveWithoutJob() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)

        do {
            try ShiftStorage(stack: stack).save(try makeShift(), forJobID: canonicalWorkTypeID)
            Issue.record("Shift сохранён без Job")
        } catch ShiftStorageError.jobNotFound {
        }
    }

    @Test("Неизвестный WorkType ID отклоняется до вставки")
    func rejectsUnknownWorkTypeIDWithoutPartialSave() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeMultiWorkTypeJob())
        let unsupportedID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let shift = try Shift(
            jobID: multiJobID,
            workTypeID: unsupportedID,
            start: start,
            end: start.addingTimeInterval(60)
        )

        do {
            try ShiftStorage(stack: stack).save(shift, forJobID: multiJobID)
            Issue.record("Shift с неизвестным WorkType был сохранён")
        } catch ShiftStorageError.workTypeNotFound(let workTypeID) {
            #expect(workTypeID == unsupportedID)
        }
        #expect(try fetchShifts(in: stack.viewContext).isEmpty)
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Legacy Job link не заменяет отсутствующий canonical Shift WorkType")
    func rejectsShiftWithMissingWorkTypeRelationship() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))

        let entityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "ShiftEntity", in: stack.viewContext)
        )
        let entity = ShiftEntity(entity: entityDescription, insertInto: stack.viewContext)
        entity.id = try #require(UUID(uuidString: "15000000-0000-0000-0000-000000000001"))
        entity.start = Date(timeIntervalSinceReferenceDate: 1_000)
        entity.end = Date(timeIntervalSinceReferenceDate: 2_000)
        entity.unpaidBreakStart = nil
        entity.unpaidBreakEnd = nil
        entity.job = job
        entity.workType = nil
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Legacy Shift.job был принят без canonical Shift.workType")
        } catch ShiftStorageError.corruptedData(
            .missingShiftWorkType(let shiftID)
        ) {
            #expect(shiftID == entity.id)
        }
    }

    @Test("Canonical WorkType не отменяет проверку отсутствующего Job mirror")
    func rejectsShiftWithMissingJobMirror() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let workType = try onlyWorkType(for: job)

        let entity = try insertShiftEntity(
            id: try #require(UUID(uuidString: "16000000-0000-0000-0000-000000000001")),
            job: nil,
            workType: workType,
            start: Date(timeIntervalSinceReferenceDate: 1_000),
            end: Date(timeIntervalSinceReferenceDate: 2_000),
            in: stack.viewContext
        )

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Shift без Job compatibility mirror был принят")
        } catch ShiftStorageError.corruptedData(
            .missingShiftJobRelationship(let shiftID)
        ) {
            #expect(shiftID == entity.id)
        }
    }

    @Test("Job без canonical WorkType отклоняется")
    func rejectsMissingWorkType() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(
            id: try #require(UUID(uuidString: "17000000-0000-0000-0000-000000000001")),
            includeWorkType: false,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: try #require(UUID(uuidString: "17000000-0000-0000-0000-000000000001")))
            Issue.record("Job без canonical WorkType была принята")
        } catch ShiftStorageError.corruptedData(.missingWorkType) {
        }
    }

    @Test("Повторяющийся WorkType ID отклоняется как corruption")
    func rejectsDuplicateWorkTypeIdentity() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let duplicateWorkTypeID = try #require(
            UUID(uuidString: "18000000-0000-0000-0000-000000000002")
        )
        _ = try insertPersistedJob(
            id: try #require(UUID(uuidString: "18000000-0000-0000-0000-000000000001")),
            workTypeID: duplicateWorkTypeID,
            additionalWorkTypeID: duplicateWorkTypeID,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: try #require(UUID(uuidString: "18000000-0000-0000-0000-000000000001")))
            Issue.record("Повторяющийся WorkType ID был принят")
        } catch ShiftStorageError.corruptedData(
            .duplicateWorkTypeIdentity(let workTypeID)
        ) {
            #expect(workTypeID == duplicateWorkTypeID)
        }
    }

    @Test("История указанной Job доступна при двух persisted Jobs")
    func loadsRequestedJobWithMultipleJobs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try insertPersistedJob(id: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001")), in: stack.viewContext)
        try insertPersistedJob(id: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000002")), in: stack.viewContext)
        try stack.viewContext.save()

        let jobID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001"))
        #expect(try ShiftStorage(stack: stack).loadAll(forJobID: jobID).isEmpty)
    }

    @Test("Частичная пара break-дат — corruption")
    func rejectsPartialBreakPair() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let workType = try onlyWorkType(for: job)
        let entityDescription = try #require(NSEntityDescription.entity(forEntityName: "ShiftEntity", in: stack.viewContext))
        let entity = ShiftEntity(entity: entityDescription, insertInto: stack.viewContext)
        entity.id = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        entity.start = Date(timeIntervalSinceReferenceDate: 1_000)
        entity.end = Date(timeIntervalSinceReferenceDate: 2_000)
        entity.unpaidBreakStart = Date(timeIntervalSinceReferenceDate: 1_200)
        entity.unpaidBreakEnd = nil
        entity.workType = workType
        entity.job = job
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Частичная пара break-дат была принята")
        } catch ShiftStorageError.corruptedData(.invalidBreakPair) {
        }
    }

    @Test("Повреждённые границы Shift отклоняются через Domain")
    func rejectsInvalidPersistedShift() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let job = try #require(try fetchOnlyJob(in: stack.viewContext))
        let workType = try onlyWorkType(for: job)
        let entityDescription = try #require(NSEntityDescription.entity(forEntityName: "ShiftEntity", in: stack.viewContext))
        let entity = ShiftEntity(entity: entityDescription, insertInto: stack.viewContext)
        entity.id = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000001"))
        entity.start = Date(timeIntervalSinceReferenceDate: 2_000)
        entity.end = entity.start
        entity.workType = workType
        entity.job = job
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Некорректный persisted Shift был принят")
        } catch ShiftStorageError.corruptedData(.invalidShift(underlying: ShiftValidationError.startNotBeforeEnd)) {
        }
    }

    @Test("Two Job SQLite histories, exact payroll and mutation isolation survive reopen")
    func scopedHistoriesSurviveReopen() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let a = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        let b = try insertPersistedJob(id: multiJobID, workTypeID: canonicalWorkTypeID, in: stack.viewContext)
        let bWorkType = try #require(b.workType)
        bWorkType.basePayKind = StoredBasePayKind.fixedPerShift.rawValue
        b.job.basePayKind = StoredBasePayKind.fixedPerShift.rawValue
        try stack.viewContext.save()
        let storage = ShiftStorage(stack: stack)
        let first = try makeShift(id: "91000000-0000-0000-0000-000000000001")
        let second = try makeShift(id: "91000000-0000-0000-0000-000000000002", jobID: multiJobID)
        try storage.save(first, forJobID: a.job.id)
        try storage.save(second, forJobID: b.job.id)
        #expect(try storage.loadAll(forJobID: a.job.id) == [first])
        #expect(try storage.loadAll(forJobID: b.job.id) == [second])
        let domainA = try makeJob()
        let domainB = try Job(
            id: multiJobID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [WorkType(
                id: canonicalWorkTypeID, basePayBasis: .fixedPerShift,
                payRateHistory: PayRateHistory(payRates: [PayRate(id: multiJobID, amount: 100, effectiveFrom: nil)])
            )]
        )
        #expect(try domainA.expectedGross(for: domainA.payCalculationPeriod(for: first),
                                        from: storage.loadAll(forJobID: domainA.id)) == 800)
        #expect(try domainB.expectedGross(for: domainB.payCalculationPeriod(for: second),
                                        from: storage.loadAll(forJobID: domainB.id)) == 100)
        let composition = AppFlowComposition(stack: stack).makeMainDependencies()
        let comparison = try composition.preparePaycheckComparison(
            domainA, domainA.payCalculationPeriod(for: first), ActualGross(amount: 800)
        )
        #expect(comparison.expected.expectedGross == 800)
        #expect(comparison.difference == 0)

        // JobStorage now resolves the explicit owner even with another Job persisted.
        do {
            _ = try JobStorage(stack: stack).addPayRate(
                PayRate(id: firstWorkTypeID, amount: 101, effectiveFrom: nil),
                toWorkTypeID: canonicalWorkTypeID,
                inJobID: canonicalWorkTypeID
            )
            Issue.record("JobStorage unexpectedly accepted a second undated rate")
        } catch JobStorageError.invalidPayRateChange {
            #expect(!stack.viewContext.hasChanges)
        }

        let moved = try makeShift(id: first.id.uuidString, start: 40 * 60 * 60)
        try storage.update(moved, forJobID: canonicalWorkTypeID)
        #expect(try storage.loadAll(forJobID: multiJobID) == [second])
        try close(stack)
        let reopened = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let reopenedStorage = ShiftStorage(stack: reopened)
        #expect(try reopenedStorage.loadAll(forJobID: canonicalWorkTypeID) == [moved])
        #expect(try reopenedStorage.loadAll(forJobID: multiJobID) == [second])
        let persisted = try fetchShifts(in: reopened.viewContext)
        #expect(persisted.allSatisfy { $0.job?.objectID == $0.workType?.job.objectID })
        try reopenedStorage.delete(id: moved.id, inJobID: canonicalWorkTypeID)
        try close(reopened)
        let final = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: final).loadAll(forJobID: canonicalWorkTypeID).isEmpty)
        #expect(try ShiftStorage(stack: final).loadAll(forJobID: multiJobID) == [second])
        #expect(try domainB.basePay(for: second) == 100)
    }

    @Test("Foreign target IDs cannot update, delete or reparent another Job's Shift", arguments: [false, true])
    func foreignTargetRejectsWithoutMutation(_ deleting: Bool) async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        _ = try insertPersistedJob(id: multiJobID, workTypeID: canonicalWorkTypeID, in: stack.viewContext)
        try stack.viewContext.save()
        let original = try makeShift(jobID: multiJobID)
        let storage = ShiftStorage(stack: stack)
        try storage.save(original, forJobID: multiJobID)
        let proposed = try makeShift(id: original.id.uuidString, start: 40 * 60 * 60)
        do {
            if deleting { try storage.delete(id: original.id, inJobID: canonicalWorkTypeID) }
            else { try storage.update(proposed, forJobID: canonicalWorkTypeID) }
            Issue.record("Foreign persisted Shift was mutated")
        } catch ShiftStorageError.foreignShiftOwner(let id, let expected, let actual) {
            #expect(id == original.id)
            #expect(expected == canonicalWorkTypeID)
            #expect(actual == multiJobID)
        }
        #expect(!stack.viewContext.hasChanges)
        try close(stack)
        let reopened = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: multiJobID) == [original])
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: canonicalWorkTypeID).isEmpty)
    }

    @Test("Archived Job history loads, but save/update/delete are rejected", arguments: [0, 1, 2])
    func archivedJobRejectsWrites(_ operation: Int) async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let a = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        _ = try insertPersistedJob(id: multiJobID, in: stack.viewContext)
        try stack.viewContext.save()
        let original = try makeShift()
        let storage = ShiftStorage(stack: stack)
        try storage.save(original, forJobID: canonicalWorkTypeID)
        a.job.isArchived = true
        try stack.viewContext.save()
        do {
            switch operation {
            case 0: try storage.save(makeShift(id: firstWorkTypeID.uuidString), forJobID: canonicalWorkTypeID)
            case 1: try storage.update(original, forJobID: canonicalWorkTypeID)
            default: try storage.delete(id: original.id, inJobID: canonicalWorkTypeID)
            }
            Issue.record("Archived Job accepted a write")
        } catch ShiftStorageError.jobArchived(let id) {
            #expect(id == canonicalWorkTypeID)
        }
        #expect(!stack.viewContext.hasChanges)
        let activeShift = try makeShift(id: secondWorkTypeID.uuidString, workTypeID: multiJobID, jobID: multiJobID)
        try storage.save(activeShift, forJobID: multiJobID)
        try close(stack)
        let reopened = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: canonicalWorkTypeID) == [original])
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: multiJobID) == [activeShift])
    }

    @Test("Shift identity is globally unique even across different Jobs")
    func duplicateShiftAcrossJobsRejected() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let a = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        let b = try insertPersistedJob(id: multiJobID, workTypeID: canonicalWorkTypeID, in: stack.viewContext)
        try stack.viewContext.save()
        let first = try makeShift()
        let second = try makeShift(id: first.id.uuidString, jobID: multiJobID)
        let storage = ShiftStorage(stack: stack)
        try storage.save(first, forJobID: canonicalWorkTypeID)
        do {
            try storage.save(second, forJobID: multiJobID)
            Issue.record("Duplicate identity across Jobs was inserted")
        } catch ShiftStorageError.duplicateShift {
            #expect(!stack.viewContext.hasChanges)
        }
        _ = try insertShiftEntity(id: first.id, job: b.job, workType: b.workType,
                                 start: second.start, end: second.end, in: stack.viewContext)
        try stack.viewContext.save()
        for id in [a.job.id, b.job.id] {
            do {
                _ = try storage.loadAll(forJobID: id)
                Issue.record("Cross-Job duplicate persisted identity concealed")
            } catch ShiftStorageError.corruptedData(.duplicateShiftIdentity(let duplicate)) {
                #expect(duplicate == first.id)
            }
        }
    }

    @Test("Duplicate Job identity is corruption, missing Job identity is not-found")
    func scopedJobLookupFailures() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        _ = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        try stack.viewContext.save()
        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Duplicate Job identity concealed")
        } catch ShiftStorageError.corruptedData(.duplicateJobIdentity(let id)) {
            #expect(id == canonicalWorkTypeID)
        }
        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: multiJobID)
            Issue.record("Missing Job resolved to another Job")
        } catch ShiftStorageError.jobNotFound(let id) {
            #expect(id == multiJobID)
        }
    }

    @Test("Orphan and mismatched ownership remain corruption in scoped history", arguments: [0, 1, 2])
    func scopedHistoryPreservesRelationshipIntegrity(_ corruption: Int) async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let a = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        let b = try insertPersistedJob(id: multiJobID, in: stack.viewContext)
        let shift = try makeShift()
        let entity = try insertShiftEntity(
            id: shift.id, job: corruption == 1 ? b.job : nil,
            workType: corruption == 2 ? nil : a.workType,
            start: shift.start, end: shift.end, in: stack.viewContext
        )
        do {
            _ = try ShiftStorage(stack: stack).loadAll(forJobID: canonicalWorkTypeID)
            Issue.record("Scoped query concealed corrupted relationships")
        } catch ShiftStorageError.corruptedData(let reason) {
            switch reason {
            case .missingShiftJobRelationship(let id): #expect(corruption != 1 && id == entity.id)
            case .shiftJobBelongsToDifferentJob(let id, let expected, let actual):
                #expect(corruption == 1 && id == entity.id)
                #expect(expected == canonicalWorkTypeID && actual == multiJobID)
            default: Issue.record("Unexpected corruption: \(reason)")
            }
        }
        #expect(entity.job?.objectID == (corruption == 1 ? b.job.objectID : nil))
        #expect(entity.workType?.objectID == (corruption == 2 ? nil : a.workType?.objectID))
    }

    @Test("A foreign WorkType cannot be assigned even with valid requested Shift ownership")
    func scopedAssignmentRejectsForeignWorkType() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        _ = try insertPersistedJob(id: multiJobID, in: stack.viewContext)
        try stack.viewContext.save()
        let proposed = try makeShift(workTypeID: multiJobID)
        do {
            try ShiftStorage(stack: stack).save(proposed, forJobID: canonicalWorkTypeID)
            Issue.record("Another Job's WorkType was assigned")
        } catch ShiftStorageError.workTypeNotFound(let id) {
            #expect(id == multiJobID)
        }
        #expect(!stack.viewContext.hasChanges)
        try close(stack)
        let reopened = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try fetchShifts(in: reopened.viewContext).isEmpty)
    }

    @Test("An attributable orphan of Job B is not loaded into Job A's history")
    func unrelatedCorruptionDoesNotMixHistories() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        _ = try insertPersistedJob(id: canonicalWorkTypeID, in: stack.viewContext)
        let b = try insertPersistedJob(id: multiJobID, in: stack.viewContext)
        try stack.viewContext.save()
        let storage = ShiftStorage(stack: stack)
        let original = try makeShift()
        try storage.save(original, forJobID: canonicalWorkTypeID)
        let orphan = try insertShiftEntity(
            id: secondWorkTypeID, job: nil, workType: b.workType,
            start: original.start, end: original.end, in: stack.viewContext
        )
        #expect(try storage.loadAll(forJobID: canonicalWorkTypeID) == [original])
        do {
            _ = try storage.loadAll(forJobID: multiJobID)
            Issue.record("Job B orphan was concealed")
        } catch ShiftStorageError.corruptedData(.missingShiftJobRelationship(let id)) {
            #expect(id == orphan.id)
        }
        #expect(orphan.job == nil)
    }

    private func makeShift(
        id: String = "90000000-0000-0000-0000-000000000001",
        start offset: TimeInterval = 10 * 60 * 60,
        workTypeID: UUID? = nil,
        jobID: UUID = UUID(uuid: (0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    ) throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: offset)
        return try Shift(
            id: try #require(UUID(uuidString: id)),
            jobID: jobID,
            workTypeID: workTypeID ?? canonicalWorkTypeID,
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60)
        )
    }

    private func makeJob() throws -> Job {
        try Job(
            id: try #require(UUID(uuidString: "70000000-0000-0000-0000-000000000001")),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [try PayRate(amount: 100, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 10)
        )
    }

    private func makeMultiWorkTypeJob() throws -> Job {
        let first = WorkType(
            id: firstWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: try #require(
                            UUID(uuidString: "72000000-0000-0000-0000-000000000004")
                        ),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ]
            )
        )
        let second = WorkType(
            id: secondWorkTypeID,
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: try #require(
                            UUID(uuidString: "72000000-0000-0000-0000-000000000005")
                        ),
                        amount: 500,
                        effectiveFrom: nil
                    )
                ]
            )
        )

        return try Job(
            id: multiJobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [second, first],
            createdAt: Date(timeIntervalSinceReferenceDate: 10)
        )
    }

    private func makeStack(storeURL: URL, stacks: inout [CoreDataStack]) async throws -> CoreDataStack {
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)
        return stack
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func removeTemporaryStoreDirectory(for storeURL: URL, stacks: [CoreDataStack]) {
        for stack in stacks {
            let context = stack.viewContext
            context.reset()
            if let coordinator = context.persistentStoreCoordinator {
                for store in coordinator.persistentStores {
                    try? coordinator.remove(store)
                }
            }
        }
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }

    private func fetchOnlyJob(in context: NSManagedObjectContext) throws -> JobEntity? {
        let request = NSFetchRequest<JobEntity>(entityName: "JobEntity")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchJobs(in context: NSManagedObjectContext) throws -> [JobEntity] {
        try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
    }

    private func fetchWorkTypes(
        in context: NSManagedObjectContext
    ) throws -> [WorkTypeEntity] {
        try context.fetch(NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity"))
    }

    private func fetchShifts(in context: NSManagedObjectContext) throws -> [ShiftEntity] {
        try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
    }

    private func fetchPayRates(in context: NSManagedObjectContext) throws -> [PayRateEntity] {
        try context.fetch(NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity"))
    }

    private func onlyWorkType(for job: JobEntity) throws -> WorkTypeEntity {
        let workTypes = try job.workTypes?.map { object in
            try #require(object as? WorkTypeEntity)
        } ?? []
        #expect(workTypes.count == 1)
        return try #require(workTypes.first)
    }

    private func insertShiftEntity(
        id: UUID,
        job: JobEntity?,
        workType: WorkTypeEntity?,
        start: Date,
        end: Date,
        in context: NSManagedObjectContext
    ) throws -> ShiftEntity {
        let description = try #require(
            NSEntityDescription.entity(forEntityName: "ShiftEntity", in: context)
        )
        let shift = ShiftEntity(entity: description, insertInto: context)
        shift.id = id
        shift.start = start
        shift.end = end
        shift.unpaidBreakStart = nil
        shift.unpaidBreakEnd = nil
        shift.workType = workType
        shift.job = job
        return shift
    }

    @discardableResult
    private func insertPersistedJob(
        id: UUID,
        workTypeID: UUID? = nil,
        includeWorkType: Bool = true,
        additionalWorkTypeID: UUID? = nil,
        in context: NSManagedObjectContext
    ) throws -> (job: JobEntity, workType: WorkTypeEntity?) {
        let jobDescription = try #require(NSEntityDescription.entity(forEntityName: "JobEntity", in: context))
        let workTypeDescription = try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: context)
        )
        let payRateDescription = try #require(NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context))
        let job = JobEntity(entity: jobDescription, insertInto: context)
        job.id = id
        job.currencyCode = "EUR"
        job.timeZoneIdentifier = "Europe/Stockholm"
        job.basePayKind = StoredBasePayKind.hourly.rawValue
        job.payPeriodKind = "perShift"
        job.payPeriodAnchorDate = nil
        job.createdAt = Date(timeIntervalSinceReferenceDate: 10)

        let workType: WorkTypeEntity?
        if includeWorkType {
            let entity = WorkTypeEntity(entity: workTypeDescription, insertInto: context)
            entity.id = workTypeID ?? id
            entity.basePayKind = StoredBasePayKind.hourly.rawValue
            entity.job = job
            workType = entity
        } else {
            workType = nil
        }

        if let additionalWorkTypeID {
            let additional = WorkTypeEntity(
                entity: workTypeDescription,
                insertInto: context
            )
            additional.id = additionalWorkTypeID
            additional.basePayKind = StoredBasePayKind.hourly.rawValue
            additional.job = job
        }

        let payRate = PayRateEntity(entity: payRateDescription, insertInto: context)
        payRate.id = id
        payRate.amount = NSDecimalNumber(decimal: 100)
        payRate.effectiveFrom = nil
        payRate.job = job
        payRate.workType = workType

        return (job, workType)
    }

    private func close(_ stack: CoreDataStack) throws {
        let context = stack.viewContext
        context.reset()
        let coordinator = try #require(context.persistentStoreCoordinator)
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }
}
