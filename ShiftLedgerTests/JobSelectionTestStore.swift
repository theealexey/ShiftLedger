import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
final class JobSelectionTestStore {
    let stack: CoreDataStack
    let storeURL: URL

    private init(stack: CoreDataStack, storeURL: URL) {
        self.stack = stack
        self.storeURL = storeURL
    }

    static func make() async throws -> JobSelectionTestStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SL493-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("ShiftLedger.sqlite")
        return JobSelectionTestStore(stack: try await CoreDataStack.load(storeURL: url), storeURL: url)
    }

    @discardableResult
    func insertJob(index: Int, archived: Bool = false, name: String? = nil) throws -> JobEntity {
        let context = stack.viewContext
        let job = JobEntity(entity: try #require(
            NSEntityDescription.entity(forEntityName: "JobEntity", in: context)
        ), insertInto: context)
        job.id = try #require(UUID(uuidString: String(format: "%08d-0000-0000-0000-000000000001", index)))
        job.name = name
        job.isArchived = archived
        job.currencyCode = index == 1 ? "USD" : "EUR"
        job.timeZoneIdentifier = index == 1 ? "America/New_York" : "Europe/Stockholm"
        job.payPeriodKind = "perShift"
        job.createdAt = Date(timeIntervalSinceReferenceDate: Double(index * 1_000))
        let workType = WorkTypeEntity(entity: try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: context)
        ), insertInto: context)
        workType.id = try #require(UUID(uuidString: "AA000000-0000-0000-0000-000000000001"))
        workType.name = "Lectures"
        workType.basePayKind = "fixedPerShift"
        workType.job = job
        let rate = PayRateEntity(entity: try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context)
        ), insertInto: context)
        rate.id = try #require(UUID(uuidString: String(format: "%08d-0000-0000-0000-000000000002", index)))
        rate.amount = NSDecimalNumber(value: index * 100)
        rate.job = job
        rate.workType = workType
        try context.save()
        return job
    }

    func close() throws {
        stack.viewContext.reset()
        if let coordinator = stack.viewContext.persistentStoreCoordinator {
            for store in coordinator.persistentStores { try coordinator.remove(store) }
        }
        try FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }
}
