import CoreData
import Foundation
import Testing
@testable import ShiftLedger

struct CoreDataV2MigrationTests {
    enum LegacyVariant: Sendable {
        case hourlyWeekly
        case fixedPerShift

        var payBasis: LegacyCoreDataStoreFixture.PayBasis {
            switch self {
            case .hourlyWeekly:
                .hourly
            case .fixedPerShift:
                .fixedPerShift
            }
        }

        var payPeriod: LegacyCoreDataStoreFixture.PayPeriod {
            switch self {
            case .hourlyWeekly:
                .weekly
            case .fixedPerShift:
                .perShift
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
    }

    struct PayRateSnapshot: Equatable, Sendable {
        let id: UUID
        let amount: Decimal
        let effectiveFrom: Date?
        let jobID: UUID
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
        let payRates: [PayRateSnapshot]
        let shifts: [ShiftSnapshot]
    }

    @Test(
        "Current V2 model выполняет lossless lightweight migration V1 SQLite",
        arguments: [LegacyVariant.hourlyWeekly, .fixedPerShift]
    )
    @MainActor
    func migratesLegacyStoreAndReopens(_ variant: LegacyVariant) async throws {
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

        let before = try fixture.inspect { context in
            try Self.snapshot(in: context)
        }
        #expect(before.payRates.count == 3)
        #expect(before.shifts.count == 3)

        let firstContainer = try await loadCurrentContainer(storeURL: fixture.storeURL)
        containers.append(firstContainer)
        let firstOpen = try Self.snapshot(in: firstContainer.viewContext)

        #expect(firstOpen == before)
        try verifyTransitionalState(in: firstContainer.viewContext)

        try close(firstContainer)

        let secondContainer = try await loadCurrentContainer(storeURL: fixture.storeURL)
        containers.append(secondContainer)
        let secondOpen = try Self.snapshot(in: secondContainer.viewContext)

        #expect(secondOpen == before)
        try verifyTransitionalState(in: secondContainer.viewContext)
    }

    @MainActor
    private func verifyTransitionalState(
        in context: NSManagedObjectContext
    ) throws {
        let workTypes = try Self.fetch(entityName: "WorkTypeEntity", in: context)
        let jobs = try Self.fetch(entityName: "JobEntity", in: context)
        let payRates = try Self.fetch(entityName: "PayRateEntity", in: context)
        let job = try #require(jobs.first)
        let jobWorkTypes = try #require(job.value(forKey: "workTypes") as? NSSet)

        #expect(workTypes.isEmpty)
        #expect(jobWorkTypes.count == 0)
        #expect(payRates.allSatisfy { $0.value(forKey: "workType") == nil })
    }

    private static func snapshot(
        in context: NSManagedObjectContext
    ) throws -> StoreSnapshot {
        let jobs = try fetch(entityName: "JobEntity", in: context)
        let payRates = try fetch(entityName: "PayRateEntity", in: context)
        let shifts = try fetch(entityName: "ShiftEntity", in: context)
        let job = try #require(jobs.first)
        let jobPayRates = try #require(job.value(forKey: "payRates") as? NSSet)
        let jobShifts = try #require(job.value(forKey: "shifts") as? NSSet)

        #expect(jobs.count == 1)

        let payRateSnapshots = try payRates.map { payRate in
            let relatedJob = try #require(payRate.value(forKey: "job") as? NSManagedObject)
            return PayRateSnapshot(
                id: try requiredUUID(payRate, key: "id"),
                amount: try requiredDecimal(payRate, key: "amount"),
                effectiveFrom: payRate.value(forKey: "effectiveFrom") as? Date,
                jobID: try requiredUUID(relatedJob, key: "id")
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
                shiftIDs: try relatedIDs(jobShifts)
            ),
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
    private func loadCurrentContainer(
        storeURL: URL
    ) async throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ShiftLedger")
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
        let context = container.viewContext
        context.reset()
        let coordinator = container.persistentStoreCoordinator

        for persistentStore in coordinator.persistentStores {
            try coordinator.remove(persistentStore)
        }
    }
}
