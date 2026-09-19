import CoreData
import Foundation
import Testing
@testable import ShiftLedger

struct CoreDataV3MigrationTests {
    enum LegacyVariant: Sendable {
        case hourlyWeekly
        case fixedPerShift

        var payBasis: LegacyCoreDataStoreFixture.PayBasis {
            switch self {
            case .hourlyWeekly: .hourly
            case .fixedPerShift: .fixedPerShift
            }
        }

        var payPeriod: LegacyCoreDataStoreFixture.PayPeriod {
            switch self {
            case .hourlyWeekly: .weekly
            case .fixedPerShift: .perShift
            }
        }

    }

    struct JobSnapshot: Equatable, Sendable {
        let id: UUID
        let currencyCode: String
        let timeZoneIdentifier: String
        let basePayKind: String?
        let payPeriodKind: String
        let payPeriodAnchorDate: Date?
        let createdAt: Date
        let payRateIDs: Set<UUID>
        let shiftIDs: Set<UUID>
        let workTypeIDs: Set<UUID>
    }

    struct WorkTypeSnapshot: Equatable, Sendable {
        let id: UUID
        let basePayKind: String
        let jobID: UUID
        let payRateIDs: Set<UUID>
    }

    struct PayRateSnapshot: Equatable, Sendable {
        let id: UUID
        let amount: Decimal
        let effectiveFrom: Date?
        let jobID: UUID
        let workTypeID: UUID?
    }

    struct ShiftSnapshot: Equatable, Sendable {
        let id: UUID
        let start: Date
        let end: Date
        let unpaidBreakStart: Date?
        let unpaidBreakEnd: Date?
        let jobID: UUID
    }

    struct StoreSnapshot: Equatable, Sendable {
        let job: JobSnapshot
        let workTypes: [WorkTypeSnapshot]
        let payRates: [PayRateSnapshot]
        let shifts: [ShiftSnapshot]
    }

    @Test(
        "V2 SQLite lightweight-migrate в V3 без Shift backfill и переживает reopen",
        arguments: [LegacyVariant.hourlyWeekly, .fixedPerShift]
    )
    @MainActor
    func migratesV2StoreLosslesslyAndReopens(_ variant: LegacyVariant) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(
            payBasis: variant.payBasis,
            payPeriod: variant.payPeriod
        )
        var containers: [NSPersistentContainer] = []
        defer {
            close(containers)
            do {
                try fixture.remove()
            } catch {
                Issue.record(error)
            }
        }

        let v2Container = try await loadV2Container(storeURL: fixture.storeURL)
        containers.append(v2Container)
        try LegacyWorkTypeBackfill.run(in: v2Container.viewContext)
        let v2Snapshot = try Self.snapshot(in: v2Container.viewContext)

        #expect(v2Snapshot.workTypes.count == 1)
        #expect(v2Snapshot.payRates.count == 3)
        #expect(v2Snapshot.shifts.count == 3)
        #expect(v2Container.managedObjectModel.entitiesByName["ShiftEntity"]?.relationshipsByName["workType"] == nil)

        try close(v2Container)

        let firstV3Container = try await loadV3Container(storeURL: fixture.storeURL)
        containers.append(firstV3Container)
        try verifyMigratedV3(
            container: firstV3Container,
            expected: v2Snapshot
        )

        try close(firstV3Container)

        let reopenedV3Container = try await loadV3Container(storeURL: fixture.storeURL)
        containers.append(reopenedV3Container)
        try verifyMigratedV3(
            container: reopenedV3Container,
            expected: v2Snapshot
        )
    }

    @MainActor
    private func verifyMigratedV3(
        container: NSPersistentContainer,
        expected: StoreSnapshot
    ) throws {
        let context = container.viewContext
        let actual = try Self.snapshot(in: context)
        #expect(actual == expected)

        let shifts = try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
        let workTypes = try context.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let workType = try #require(workTypes.first)

        #expect(workTypes.count == 1)
        #expect(shifts.count == 3)
        #expect(shifts.allSatisfy { $0.workType == nil })
        #expect((workType.shifts?.count ?? 0) == 0)
    }

    private static func snapshot(
        in context: NSManagedObjectContext
    ) throws -> StoreSnapshot {
        let jobs = try fetch(entityName: "JobEntity", in: context)
        let workTypes = try fetch(entityName: "WorkTypeEntity", in: context)
        let payRates = try fetch(entityName: "PayRateEntity", in: context)
        let shifts = try fetch(entityName: "ShiftEntity", in: context)
        let job = try #require(jobs.first)

        #expect(jobs.count == 1)

        let jobPayRates = try requiredSet(job, key: "payRates")
        let jobShifts = try requiredSet(job, key: "shifts")
        let jobWorkTypes = try requiredSet(job, key: "workTypes")

        let workTypeSnapshots = try workTypes.map { workType in
            let relatedJob = try #require(workType.value(forKey: "job") as? NSManagedObject)
            return WorkTypeSnapshot(
                id: try requiredUUID(workType, key: "id"),
                basePayKind: try requiredString(workType, key: "basePayKind"),
                jobID: try requiredUUID(relatedJob, key: "id"),
                payRateIDs: try relatedIDs(requiredSet(workType, key: "payRates"))
            )
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }

        let payRateSnapshots = try payRates.map { payRate in
            let relatedJob = try #require(payRate.value(forKey: "job") as? NSManagedObject)
            let relatedWorkType = payRate.value(forKey: "workType") as? NSManagedObject
            return PayRateSnapshot(
                id: try requiredUUID(payRate, key: "id"),
                amount: try requiredDecimal(payRate, key: "amount"),
                effectiveFrom: payRate.value(forKey: "effectiveFrom") as? Date,
                jobID: try requiredUUID(relatedJob, key: "id"),
                workTypeID: try relatedWorkType.map { try requiredUUID($0, key: "id") }
            )
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }

        let shiftSnapshots = try shifts.map { shift in
            let relatedJob = try #require(shift.value(forKey: "job") as? NSManagedObject)
            return ShiftSnapshot(
                id: try requiredUUID(shift, key: "id"),
                start: try requiredDate(shift, key: "start"),
                end: try requiredDate(shift, key: "end"),
                unpaidBreakStart: shift.value(forKey: "unpaidBreakStart") as? Date,
                unpaidBreakEnd: shift.value(forKey: "unpaidBreakEnd") as? Date,
                jobID: try requiredUUID(relatedJob, key: "id")
            )
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }

        return StoreSnapshot(
            job: JobSnapshot(
                id: try requiredUUID(job, key: "id"),
                currencyCode: try requiredString(job, key: "currencyCode"),
                timeZoneIdentifier: try requiredString(job, key: "timeZoneIdentifier"),
                basePayKind: job.value(forKey: "basePayKind") as? String,
                payPeriodKind: try requiredString(job, key: "payPeriodKind"),
                payPeriodAnchorDate: job.value(forKey: "payPeriodAnchorDate") as? Date,
                createdAt: try requiredDate(job, key: "createdAt"),
                payRateIDs: try relatedIDs(jobPayRates),
                shiftIDs: try relatedIDs(jobShifts),
                workTypeIDs: try relatedIDs(jobWorkTypes)
            ),
            workTypes: workTypeSnapshots,
            payRates: payRateSnapshots,
            shifts: shiftSnapshots
        )
    }

    private static func fetch(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
    }

    private static func requiredSet(
        _ object: NSManagedObject,
        key: String
    ) throws -> NSSet {
        try #require(object.value(forKey: key) as? NSSet)
    }

    private static func relatedIDs(_ relationship: NSSet) throws -> Set<UUID> {
        Set(try relationship.map { object in
            let managedObject = try #require(object as? NSManagedObject)
            return try requiredUUID(managedObject, key: "id")
        })
    }

    private static func requiredUUID(
        _ object: NSManagedObject,
        key: String
    ) throws -> UUID {
        try #require(object.value(forKey: key) as? UUID)
    }

    private static func requiredString(
        _ object: NSManagedObject,
        key: String
    ) throws -> String {
        try #require(object.value(forKey: key) as? String)
    }

    private static func requiredDate(
        _ object: NSManagedObject,
        key: String
    ) throws -> Date {
        try #require(object.value(forKey: key) as? Date)
    }

    private static func requiredDecimal(
        _ object: NSManagedObject,
        key: String
    ) throws -> Decimal {
        try #require(object.value(forKey: key) as? NSDecimalNumber).decimalValue
    }

    @MainActor
    private func loadV2Container(
        storeURL: URL
    ) async throws -> NSPersistentContainer {
        try await loadContainer(modelName: "ShiftLedgerV2", storeURL: storeURL)
    }

    @MainActor
    private func loadV3Container(
        storeURL: URL
    ) async throws -> NSPersistentContainer {
        try await loadContainer(modelName: "ShiftLedgerV3", storeURL: storeURL)
    }

    @MainActor
    private func loadContainer(
        modelName: String,
        storeURL: URL
    ) async throws -> NSPersistentContainer {
        let packageURL = try #require(
            Bundle.main.url(forResource: "ShiftLedger", withExtension: "momd")
        )
        let modelURL = packageURL
            .appendingPathComponent(modelName)
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

    @MainActor
    private func close(_ containers: [NSPersistentContainer]) {
        for container in containers {
            do {
                try close(container)
            } catch {
                Issue.record(error)
            }
        }
    }

    @MainActor
    private func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

}
