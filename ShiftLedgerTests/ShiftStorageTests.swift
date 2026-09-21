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

    @Test("Смена без перерыва переживает SQLite reopen")
    func roundTripsShiftWithoutBreak() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let shift = try makeShift(id: "8A3B3F10-1F62-4E7D-8D25-8BBD5A37DF11", start: 10 * 60 * 60)
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let job = try makeJob()
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(shift)

        #expect(try ShiftStorage(stack: stackA).loadAll() == [shift])

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
        let loaded = try #require(try ShiftStorage(stack: stackB).loadAll().first)
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
        try ShiftStorage(stack: stackA).save(shift)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let loaded = try #require(try ShiftStorage(stack: stackB).loadAll().first)
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
            workTypeID: firstWorkTypeID
        )
        let secondShift = try makeShift(
            id: "72000000-0000-0000-0000-000000000012",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID
        )
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(firstShift)
        try ShiftStorage(stack: stackA).save(secondShift)

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
        let loaded = try ShiftStorage(stack: stackB).loadAll()

        #expect(loaded == [firstShift, secondShift])
        #expect(loaded.map(\.workTypeID) == [firstWorkTypeID, secondWorkTypeID])
        #expect(try fetchWorkTypes(in: stackB.viewContext).count == 2)
        #expect(try fetchShifts(in: stackB.viewContext).count == 2)
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
            workTypeID: firstWorkTypeID
        )
        let unrelated = try makeShift(
            id: "74000000-0000-0000-0000-000000000002",
            start: 50 * 60 * 60,
            workTypeID: firstWorkTypeID
        )
        let storage = ShiftStorage(stack: stackA)
        try storage.save(original)
        try storage.save(unrelated)

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
            workTypeID: secondWorkTypeID,
            start: updatedStart,
            end: updatedStart.addingTimeInterval(10 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: updatedStart.addingTimeInterval(4 * 60 * 60),
                end: updatedStart.addingTimeInterval(5 * 60 * 60)
            )
        )

        try storage.update(updated)

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
        #expect(try storage.loadAll() == [updated, unrelated])
        #expect(stackA.viewContext.hasChanges == false)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: stackB).loadAll() == [updated, unrelated])
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
        try storage.save(shift)
        let objectID = try #require(try fetchShifts(in: stack.viewContext).first).objectID

        try storage.update(shift)

        let persisted = try fetchShifts(in: stack.viewContext)
        #expect(persisted.count == 1)
        #expect(persisted.first?.objectID == objectID)
        #expect(try storage.loadAll() == [shift])
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
            workTypeID: firstWorkTypeID
        )
        let other = try makeShift(
            id: "76000000-0000-0000-0000-000000000002",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target)
        try storage.save(other)
        let targetObjectID = try #require(
            try fetchShifts(in: stack.viewContext).first { $0.id == target.id }
        ).objectID
        let proposedStart = Date(timeIntervalSinceReferenceDate: 19 * 60 * 60)
        let proposed = try Shift(
            id: target.id,
            workTypeID: firstWorkTypeID,
            start: proposedStart,
            end: proposedStart.addingTimeInterval(2 * 60 * 60)
        )

        do {
            try storage.update(proposed)
            Issue.record("Пересекающийся update был сохранён")
        } catch ShiftStorageError.overlappingShift {
        }

        let persistedTarget = try #require(
            try fetchShifts(in: stack.viewContext).first { $0.id == target.id }
        )
        #expect(persistedTarget.objectID == targetObjectID)
        #expect(try storage.loadAll() == [target, other])
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
            workTypeID: firstWorkTypeID
        )
        let other = try makeShift(
            id: "77000000-0000-0000-0000-000000000002",
            start: 20 * 60 * 60,
            workTypeID: secondWorkTypeID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target)
        try storage.save(other)
        let adjacentStart = Date(timeIntervalSinceReferenceDate: 12 * 60 * 60)
        let adjacent = try Shift(
            id: target.id,
            workTypeID: firstWorkTypeID,
            start: adjacentStart,
            end: other.start
        )

        try storage.update(adjacent)

        #expect(try storage.loadAll() == [adjacent, other])
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
            workTypeID: firstWorkTypeID
        )
        let storage = ShiftStorage(stack: stack)
        try storage.save(target)
        let unknownID = UUID(uuid: (0x78, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
        let proposed = try Shift(
            id: target.id,
            workTypeID: unknownID,
            start: target.start.addingTimeInterval(60),
            end: target.end.addingTimeInterval(60)
        )

        do {
            try storage.update(proposed)
            Issue.record("Update с неизвестным WorkType был сохранён")
        } catch ShiftStorageError.workTypeNotFound(let workTypeID) {
            #expect(workTypeID == unknownID)
        }

        #expect(try storage.loadAll() == [target])
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
        try storage.save(existing)
        let missing = try makeShift(id: "79000000-0000-0000-0000-000000000002")

        do {
            try storage.update(missing)
            Issue.record("Отсутствующий Shift был обновлён")
        } catch ShiftStorageError.shiftNotFound(let shiftID) {
            #expect(shiftID == missing.id)
        }

        #expect(try storage.loadAll() == [existing])
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
            workTypeID: canonicalWorkTypeID,
            start: Date(timeIntervalSinceReferenceDate: 50 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 58 * 60 * 60)
        )

        do {
            try ShiftStorage(stack: stack).update(proposed)
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
            workTypeID: canonicalWorkTypeID,
            start: Date(timeIntervalSinceReferenceDate: 20 * 60 * 60),
            end: Date(timeIntervalSinceReferenceDate: 28 * 60 * 60)
        )

        do {
            try ShiftStorage(stack: stack).update(proposed)
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
            workTypeID: workTypeID
        )
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(job)
        try ShiftStorage(stack: stackA).save(shift)

        let persistedShift = try #require(try fetchShifts(in: stackA.viewContext).first)
        #expect(persistedShift.workType?.id == workTypeID)
        #expect(persistedShift.workType?.id != jobID)

        try close(stackA)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        #expect(try ShiftStorage(stack: stackB).loadAll() == [shift])
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
        try ShiftStorage(stack: stack).save(first)
        try ShiftStorage(stack: stack).save(second)

        #expect(try ShiftStorage(stack: stack).loadAll() == [second, first])
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
            workTypeID: firstWorkTypeID
        )
        try ShiftStorage(stack: stack).save(first)

        do {
            try ShiftStorage(stack: stack).save(first)
            Issue.record("Дубликат Shift UUID был сохранён")
        } catch ShiftStorageError.duplicateShift {
        }

        let adjacent = try makeShift(
            id: "A0000000-0000-0000-0000-000000000002",
            start: 18 * 60 * 60,
            workTypeID: secondWorkTypeID
        )
        try ShiftStorage(stack: stack).save(adjacent)

        let overlapping = try makeShift(
            id: "A0000000-0000-0000-0000-000000000003",
            start: 17 * 60 * 60 + 59 * 60,
            workTypeID: secondWorkTypeID
        )
        do {
            try ShiftStorage(stack: stack).save(overlapping)
            Issue.record("Пересекающаяся Shift была сохранена")
        } catch ShiftStorageError.overlappingShift {
        }

        #expect(try ShiftStorage(stack: stack).loadAll() == [first, adjacent])
    }

    @Test("Без Job сохранение отклоняется typed jobNotFound")
    func rejectsSaveWithoutJob() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)

        do {
            try ShiftStorage(stack: stack).save(try makeShift())
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
            workTypeID: unsupportedID,
            start: start,
            end: start.addingTimeInterval(60)
        )

        do {
            try ShiftStorage(stack: stack).save(shift)
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
            _ = try ShiftStorage(stack: stack).loadAll()
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
            _ = try ShiftStorage(stack: stack).loadAll()
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
            _ = try ShiftStorage(stack: stack).loadAll()
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
            _ = try ShiftStorage(stack: stack).loadAll()
            Issue.record("Повторяющийся WorkType ID был принят")
        } catch ShiftStorageError.corruptedData(
            .duplicateWorkTypeIdentity(let workTypeID)
        ) {
            #expect(workTypeID == duplicateWorkTypeID)
        }
    }

    @Test("Две Job отклоняются как multipleJobsFound")
    func rejectsMultipleJobs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }
        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try insertPersistedJob(id: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001")), in: stack.viewContext)
        try insertPersistedJob(id: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000002")), in: stack.viewContext)
        try stack.viewContext.save()

        do {
            _ = try ShiftStorage(stack: stack).loadAll()
            Issue.record("Несколько Job были приняты")
        } catch ShiftStorageError.multipleJobsFound {
        }
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
            _ = try ShiftStorage(stack: stack).loadAll()
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
            _ = try ShiftStorage(stack: stack).loadAll()
            Issue.record("Некорректный persisted Shift был принят")
        } catch ShiftStorageError.corruptedData(.invalidShift(underlying: ShiftValidationError.startNotBeforeEnd)) {
        }
    }

    private func makeShift(
        id: String = "90000000-0000-0000-0000-000000000001",
        start offset: TimeInterval = 10 * 60 * 60,
        workTypeID: UUID? = nil
    ) throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: offset)
        return try Shift(
            id: try #require(UUID(uuidString: id)),
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
        payRate.id = UUID()
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
