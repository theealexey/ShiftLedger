import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct CoreDataV4MigrationTests {
    private let jobID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let lectureWorkTypeID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let examWorkTypeID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    private let lecturePayRateID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
    private let examPayRateID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5))
    private let shiftID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6))
    private let shiftStart = Date(timeIntervalSinceReferenceDate: 800_000)

    @Test("V3 SQLite migrates to V4 with truthful nil WorkType names and reopens")
    func migratesV3StoreWithoutFabricatingNames() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var v3Containers: [NSPersistentContainer] = []
        var stacks: [CoreDataStack] = []
        defer {
            close(v3Containers)
            close(stacks)
            do {
                try FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
            } catch {
                Issue.record(error)
            }
        }

        let v3Container = try await loadV3Container(storeURL: storeURL)
        v3Containers.append(v3Container)
        #expect(
            v3Container.managedObjectModel.entitiesByName["WorkTypeEntity"]?
                .attributesByName["name"] == nil
        )
        try insertV3Graph(in: v3Container.viewContext)
        try v3Container.viewContext.save()
        try close(v3Container)

        let firstV4Stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(firstV4Stack)
        try verifyMigratedV4(in: firstV4Stack)
        try close(firstV4Stack)

        let reopenedV4Stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(reopenedV4Stack)
        try verifyMigratedV4(in: reopenedV4Stack)
    }

    private func insertV3Graph(in context: NSManagedObjectContext) throws {
        let job = try insertObject(entityName: "JobEntity", in: context)
        job.setValue(jobID, forKey: "id")
        job.setValue("EUR", forKey: "currencyCode")
        job.setValue("Europe/Stockholm", forKey: "timeZoneIdentifier")
        job.setValue(nil, forKey: "basePayKind")
        job.setValue("perShift", forKey: "payPeriodKind")
        job.setValue(nil, forKey: "payPeriodAnchorDate")
        job.setValue(Date(timeIntervalSinceReferenceDate: 700_000), forKey: "createdAt")

        let lecture = try insertObject(entityName: "WorkTypeEntity", in: context)
        lecture.setValue(lectureWorkTypeID, forKey: "id")
        lecture.setValue("hourly", forKey: "basePayKind")
        lecture.setValue(job, forKey: "job")

        let exam = try insertObject(entityName: "WorkTypeEntity", in: context)
        exam.setValue(examWorkTypeID, forKey: "id")
        exam.setValue("fixedPerShift", forKey: "basePayKind")
        exam.setValue(job, forKey: "job")

        let lectureRate = try insertObject(entityName: "PayRateEntity", in: context)
        lectureRate.setValue(lecturePayRateID, forKey: "id")
        lectureRate.setValue(NSDecimalNumber(string: "125.50"), forKey: "amount")
        lectureRate.setValue(nil, forKey: "effectiveFrom")
        lectureRate.setValue(job, forKey: "job")
        lectureRate.setValue(lecture, forKey: "workType")

        let examRate = try insertObject(entityName: "PayRateEntity", in: context)
        examRate.setValue(examPayRateID, forKey: "id")
        examRate.setValue(NSDecimalNumber(string: "650"), forKey: "amount")
        examRate.setValue(nil, forKey: "effectiveFrom")
        examRate.setValue(job, forKey: "job")
        examRate.setValue(exam, forKey: "workType")

        let shift = try insertObject(entityName: "ShiftEntity", in: context)
        shift.setValue(shiftID, forKey: "id")
        shift.setValue(shiftStart, forKey: "start")
        shift.setValue(shiftStart.addingTimeInterval(2 * 60 * 60), forKey: "end")
        shift.setValue(nil, forKey: "unpaidBreakStart")
        shift.setValue(nil, forKey: "unpaidBreakEnd")
        shift.setValue(job, forKey: "job")
        shift.setValue(lecture, forKey: "workType")
    }

    private func verifyMigratedV4(in stack: CoreDataStack) throws {
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
        let lecture = try #require(workTypes.first { $0.id == lectureWorkTypeID })
        let exam = try #require(workTypes.first { $0.id == examWorkTypeID })
        let lectureRate = try #require(payRates.first { $0.id == lecturePayRateID })
        let examRate = try #require(payRates.first { $0.id == examPayRateID })
        let shift = try #require(shifts.first)

        #expect(jobs.count == 1)
        #expect(job.id == jobID)
        #expect(workTypes.count == 2)
        #expect(workTypes.allSatisfy { $0.name == nil })
        #expect(lecture.basePayKind == "hourly")
        #expect(exam.basePayKind == "fixedPerShift")
        #expect(lecture.job.objectID == job.objectID)
        #expect(exam.job.objectID == job.objectID)
        #expect(payRates.count == 2)
        #expect(lectureRate.amount.decimalValue == NSDecimalNumber(string: "125.50").decimalValue)
        #expect(examRate.amount.decimalValue == Decimal(650))
        #expect(lectureRate.effectiveFrom == nil)
        #expect(examRate.effectiveFrom == nil)
        #expect(lectureRate.job.objectID == job.objectID)
        #expect(examRate.job.objectID == job.objectID)
        #expect(lectureRate.workType?.objectID == lecture.objectID)
        #expect(examRate.workType?.objectID == exam.objectID)
        #expect(shifts.count == 1)
        #expect(shift.id == shiftID)
        #expect(shift.start == shiftStart)
        #expect(shift.end == shiftStart.addingTimeInterval(2 * 60 * 60))
        #expect(shift.unpaidBreakStart == nil)
        #expect(shift.unpaidBreakEnd == nil)
        #expect(shift.job?.objectID == job.objectID)
        #expect(shift.workType?.objectID == lecture.objectID)

        let domainJob = try #require(try JobStorage(stack: stack).load())
        #expect(domainJob.id == jobID)
        #expect(domainJob.workTypes.count == 2)
        #expect(domainJob.workType(id: lectureWorkTypeID)?.name == nil)
        #expect(domainJob.workType(id: examWorkTypeID)?.name == nil)
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

    private func loadV3Container(storeURL: URL) async throws -> NSPersistentContainer {
        let packageURL = try #require(
            Bundle.main.url(forResource: "ShiftLedger", withExtension: "momd")
        )
        let modelURL = packageURL
            .appendingPathComponent("ShiftLedgerV3")
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
        let context = stack.viewContext
        context.reset()
        guard let coordinator = context.persistentStoreCoordinator else {
            return
        }
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }
}
