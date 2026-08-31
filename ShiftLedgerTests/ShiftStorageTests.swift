import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftStorageTests {
    @Test("Смена без перерыва переживает SQLite reopen")
    func roundTripsShiftWithoutBreak() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let shift = try makeShift(id: "8A3B3F10-1F62-4E7D-8D25-8BBD5A37DF11", start: 10 * 60 * 60)
        let stackA = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stackA).save(try makeJob())
        try ShiftStorage(stack: stackA).save(shift)

        let stackB = try await makeStack(storeURL: storeURL, stacks: &stacks)
        let loaded = try #require(try ShiftStorage(stack: stackB).loadAll().first)
        #expect(loaded == shift)
        #expect(loaded.unpaidBreak == nil)
    }

    @Test("Смена с неоплачиваемым перерывом переживает SQLite reopen")
    func roundTripsShiftWithBreak() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let start = Date(timeIntervalSinceReferenceDate: 20_000)
        let shift = try Shift(
            id: try #require(UUID(uuidString: "2E80C3A1-7F3C-4D6C-BDA9-1E62C2A4A1F4")),
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
        #expect(loaded.start == shift.start)
        #expect(loaded.end == shift.end)
        #expect(loaded.unpaidBreak == shift.unpaidBreak)
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

    @Test("Дубликат UUID отклоняется, соседняя смена принимается, overlap отклоняется")
    func enforcesInsertAndOverlapRules() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await makeStack(storeURL: storeURL, stacks: &stacks)
        try JobStorage(stack: stack).save(try makeJob())
        let first = try makeShift(id: "A0000000-0000-0000-0000-000000000001", start: 10 * 60 * 60)
        try ShiftStorage(stack: stack).save(first)

        do {
            try ShiftStorage(stack: stack).save(first)
            Issue.record("Дубликат Shift UUID был сохранён")
        } catch ShiftStorageError.duplicateShift {
        }

        let adjacent = try makeShift(id: "A0000000-0000-0000-0000-000000000002", start: 18 * 60 * 60)
        try ShiftStorage(stack: stack).save(adjacent)

        let overlapping = try makeShift(id: "A0000000-0000-0000-0000-000000000003", start: 17 * 60 * 60 + 59 * 60)
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
        let entityDescription = try #require(NSEntityDescription.entity(forEntityName: "ShiftEntity", in: stack.viewContext))
        let entity = ShiftEntity(entity: entityDescription, insertInto: stack.viewContext)
        entity.id = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        entity.start = Date(timeIntervalSinceReferenceDate: 1_000)
        entity.end = Date(timeIntervalSinceReferenceDate: 2_000)
        entity.unpaidBreakStart = Date(timeIntervalSinceReferenceDate: 1_200)
        entity.unpaidBreakEnd = nil
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
        let entityDescription = try #require(NSEntityDescription.entity(forEntityName: "ShiftEntity", in: stack.viewContext))
        let entity = ShiftEntity(entity: entityDescription, insertInto: stack.viewContext)
        entity.id = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000001"))
        entity.start = Date(timeIntervalSinceReferenceDate: 2_000)
        entity.end = entity.start
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
        start offset: TimeInterval = 10 * 60 * 60
    ) throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: offset)
        return try Shift(
            id: try #require(UUID(uuidString: id)),
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

    private func insertPersistedJob(id: UUID, in context: NSManagedObjectContext) throws {
        let jobDescription = try #require(NSEntityDescription.entity(forEntityName: "JobEntity", in: context))
        let payRateDescription = try #require(NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context))
        let job = JobEntity(entity: jobDescription, insertInto: context)
        job.id = id
        job.currencyCode = "EUR"
        job.timeZoneIdentifier = "Europe/Stockholm"
        job.payPeriodKind = "perShift"
        job.payPeriodAnchorDate = nil
        job.createdAt = Date(timeIntervalSinceReferenceDate: 10)

        let payRate = PayRateEntity(entity: payRateDescription, insertInto: context)
        payRate.id = UUID()
        payRate.amount = NSDecimalNumber(decimal: 100)
        payRate.effectiveFrom = nil
        payRate.job = job
    }
}
