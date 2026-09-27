import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct CoreDataV5MigrationTests {
    private let jobID = UUID(uuid: (0x45, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let workTypeID = UUID(uuid: (0x45, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let initialRateID = UUID(uuid: (0x45, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    private let datedRateID = UUID(uuid: (0x45, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
    private let shiftID = UUID(uuid: (0x45, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5))

    @Test("V4 SQLite migrates to V5 with active WorkTypes and preserves the graph")
    func migratesV4StoreWithDefaultArchiveStateAndReopens() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var containers: [NSPersistentContainer] = []
        var stacks: [CoreDataStack] = []
        defer {
            close(containers)
            close(stacks)
            do {
                try FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
            } catch {
                Issue.record(error)
            }
        }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let effectiveDate = try LocalDate(year: 2026, month: 2, day: 1)
        let shiftDate = try LocalDate(year: 2026, month: 2, day: 2)
        let shiftStart = try shiftDate.startOfDay(in: timeZone)
            .addingTimeInterval(9 * 60 * 60)
        let expectedShift = try Shift(
            id: shiftID,
            workTypeID: workTypeID,
            start: shiftStart,
            end: shiftStart.addingTimeInterval(2 * 60 * 60)
        )
        let expectedJob = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [
                WorkType(
                    id: workTypeID,
                    name: "Lectures",
                    basePayBasis: .hourly,
                    payRateHistory: try PayRateHistory(payRates: [
                        try PayRate(id: initialRateID, amount: 100, effectiveFrom: nil),
                        try PayRate(
                            id: datedRateID,
                            amount: 125,
                            effectiveFrom: effectiveDate
                        )
                    ])
                )
            ],
            createdAt: Date(timeIntervalSinceReferenceDate: 900_000)
        )
        let expectedGross = try expectedJob.expectedGross(
            for: .perShift(shiftID: shiftID),
            from: [expectedShift]
        )

        let v4Container = try await loadV4Container(storeURL: storeURL)
        containers.append(v4Container)
        let v4Context = v4Container.viewContext
        let job = try insertObject(entityName: "JobEntity", in: v4Context)
        job.setValue(jobID, forKey: "id")
        job.setValue("EUR", forKey: "currencyCode")
        job.setValue("Europe/Stockholm", forKey: "timeZoneIdentifier")
        job.setValue(nil, forKey: "basePayKind")
        job.setValue("perShift", forKey: "payPeriodKind")
        job.setValue(nil, forKey: "payPeriodAnchorDate")
        job.setValue(expectedJob.createdAt, forKey: "createdAt")

        let workType = try insertObject(entityName: "WorkTypeEntity", in: v4Context)
        workType.setValue(workTypeID, forKey: "id")
        workType.setValue("Lectures", forKey: "name")
        workType.setValue("hourly", forKey: "basePayKind")
        workType.setValue(job, forKey: "job")

        let initialRate = try insertObject(entityName: "PayRateEntity", in: v4Context)
        initialRate.setValue(initialRateID, forKey: "id")
        initialRate.setValue(NSDecimalNumber(string: "100"), forKey: "amount")
        initialRate.setValue(nil, forKey: "effectiveFrom")
        initialRate.setValue(job, forKey: "job")
        initialRate.setValue(workType, forKey: "workType")

        let datedRate = try insertObject(entityName: "PayRateEntity", in: v4Context)
        datedRate.setValue(datedRateID, forKey: "id")
        datedRate.setValue(NSDecimalNumber(string: "125"), forKey: "amount")
        datedRate.setValue(try effectiveDate.startOfDay(in: timeZone), forKey: "effectiveFrom")
        datedRate.setValue(job, forKey: "job")
        datedRate.setValue(workType, forKey: "workType")

        let shift = try insertObject(entityName: "ShiftEntity", in: v4Context)
        shift.setValue(shiftID, forKey: "id")
        shift.setValue(expectedShift.start, forKey: "start")
        shift.setValue(expectedShift.end, forKey: "end")
        shift.setValue(nil, forKey: "unpaidBreakStart")
        shift.setValue(nil, forKey: "unpaidBreakEnd")
        shift.setValue(job, forKey: "job")
        shift.setValue(workType, forKey: "workType")
        try v4Context.save()
        try close(v4Container)

        let firstV5Stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(firstV5Stack)
        try verifyMigratedV5(
            in: firstV5Stack,
            expectedJob: expectedJob,
            expectedShift: expectedShift,
            expectedGross: expectedGross
        )
        try close(firstV5Stack)

        let reopenedV5Stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(reopenedV5Stack)
        try verifyMigratedV5(
            in: reopenedV5Stack,
            expectedJob: expectedJob,
            expectedShift: expectedShift,
            expectedGross: expectedGross
        )
    }

    private func verifyMigratedV5(
        in stack: CoreDataStack,
        expectedJob: Job,
        expectedShift: Shift,
        expectedGross: Decimal
    ) throws {
        let context = stack.viewContext
        let jobs = try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
        let workTypes = try context.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let payRates = try context.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let shifts = try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
        let job = try #require(jobs.first)
        let workType = try #require(workTypes.first)
        let shift = try #require(shifts.first)

        #expect(jobs.count == 1)
        #expect(workTypes.count == 1)
        #expect(payRates.count == 2)
        #expect(shifts.count == 1)
        #expect(workType.isArchived == false)
        #expect(workType.job.objectID == job.objectID)
        #expect(Set(payRates.map(\.id)) == Set([initialRateID, datedRateID]))
        #expect(payRates.first { $0.id == initialRateID }?.amount.decimalValue == Decimal(100))
        #expect(payRates.first { $0.id == datedRateID }?.amount.decimalValue == Decimal(125))
        #expect(shift.id == expectedShift.id)
        #expect(shift.workType?.objectID == workType.objectID)
        #expect(shift.job?.objectID == job.objectID)

        let domainJob = try #require(try JobStorage(stack: stack).load())
        #expect(domainJob == expectedJob)
        #expect(domainJob.workType(id: workTypeID)?.isArchived == false)
        #expect(try ShiftStorage(stack: stack).loadAll() == [expectedShift])
        #expect(try domainJob.expectedGross(
            for: .perShift(shiftID: expectedShift.id),
            from: [expectedShift]
        ) == expectedGross)
        #expect(context.hasChanges == false)
    }

    private func insertObject(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let description = try #require(
            NSEntityDescription.entity(forEntityName: entityName, in: context)
        )
        return NSManagedObject(entity: description, insertInto: context)
    }

    private func loadV4Container(storeURL: URL) async throws -> NSPersistentContainer {
        let packageURL = try #require(
            Bundle.main.url(forResource: "ShiftLedger", withExtension: "momd")
        )
        let modelURL = packageURL
            .appendingPathComponent("ShiftLedgerV4")
            .appendingPathExtension("mom")
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL))
        let container = NSPersistentContainer(
            name: "ShiftLedger",
            managedObjectModel: model
        )
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation(
            isolation: MainActor.shared
        ) { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return container
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func close(_ containers: [NSPersistentContainer]) {
        for container in containers {
            do {
                try close(container)
            } catch {
                Issue.record(error)
            }
        }
    }

    private func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    private func close(_ stacks: [CoreDataStack]) {
        for stack in stacks {
            do {
                try close(stack)
            } catch {
                Issue.record(error)
            }
        }
    }

    private func close(_ stack: CoreDataStack) throws {
        stack.viewContext.reset()
        guard let coordinator = stack.viewContext.persistentStoreCoordinator else {
            return
        }
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }
}
