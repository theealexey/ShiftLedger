import CoreData
import Foundation
import Testing
@testable import ShiftLedger

struct LegacyWorkTypeBackfillTests {
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

        var expectedDomainBasis: BasePayBasis {
            switch self {
            case .hourlyWeekly:
                .hourly
            case .fixedPerShift:
                .fixedPerShift
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

    struct LegacyGraphSnapshot: Equatable, Sendable {
        let job: JobSnapshot
        let payRates: [PayRateSnapshot]
        let shifts: [ShiftSnapshot]
    }

    @Test(
        "Production stack backfill сохраняет V1 graph и переживает reopen",
        arguments: [LegacyVariant.hourlyWeekly, .fixedPerShift]
    )
    @MainActor
    func backfillsLegacyFixtureAndReopens(_ variant: LegacyVariant) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(
            payBasis: variant.payBasis,
            payPeriod: variant.payPeriod
        )
        var stacks: [CoreDataStack] = []
        defer {
            close(stacks)
            removeFixture(fixture)
        }

        let before = try fixture.inspect { context in
            try Self.legacySnapshot(in: context)
        }

        let firstStack = try await CoreDataStack.load(storeURL: fixture.storeURL)
        stacks.append(firstStack)
        let firstWorkTypeID = try verifyBackfilledGraph(
            in: firstStack.viewContext,
            expectedLegacyGraph: before,
            fixture: fixture
        )
        try verifyStorageCompatibility(
            stack: firstStack,
            fixture: fixture,
            expectedBasis: variant.expectedDomainBasis
        )

        try close(firstStack)

        let secondStack = try await CoreDataStack.load(storeURL: fixture.storeURL)
        stacks.append(secondStack)
        let secondWorkTypeID = try verifyBackfilledGraph(
            in: secondStack.viewContext,
            expectedLegacyGraph: before,
            fixture: fixture
        )

        #expect(secondWorkTypeID == firstWorkTypeID)
    }

    @Test("Partial backfill дополняет связи без второго WorkType")
    @MainActor
    func completesPartialState() async throws {
        let store = try await makeEmptyStore()
        defer { removeStore(store) }

        let jobID = try uuid("41000000-0000-0000-0000-000000000001")
        let graph = try insertJob(
            id: jobID,
            basePayKind: "hourly",
            rateIDs: [
                try uuid("42000000-0000-0000-0000-000000000001"),
                try uuid("42000000-0000-0000-0000-000000000002")
            ],
            into: store.stack.viewContext
        )
        let workType = try insertWorkType(
            id: jobID,
            basePayKind: "hourly",
            job: graph.job,
            into: store.stack.viewContext
        )
        graph.payRates[0].workType = workType
        try store.stack.viewContext.save()

        try LegacyWorkTypeBackfill.run(in: store.stack.viewContext)

        let workTypes = try fetchWorkTypes(in: store.stack.viewContext)
        #expect(workTypes.count == 1)
        #expect(workTypes[0].objectID == workType.objectID)
        #expect(graph.payRates.allSatisfy { $0.workType?.objectID == workType.objectID })

        try LegacyWorkTypeBackfill.run(in: store.stack.viewContext)
        #expect(try fetchWorkTypes(in: store.stack.viewContext).count == 1)
        #expect(store.stack.viewContext.hasChanges == false)
    }

    @Test("Backfill создаёт отдельный default WorkType для каждой Job")
    @MainActor
    func backfillsMultipleJobsWithoutCrossLinking() async throws {
        let store = try await makeEmptyStore()
        defer { removeStore(store) }

        let first = try insertJob(
            id: try uuid("51000000-0000-0000-0000-000000000001"),
            basePayKind: nil,
            rateIDs: [try uuid("52000000-0000-0000-0000-000000000001")],
            into: store.stack.viewContext
        )
        let second = try insertJob(
            id: try uuid("51000000-0000-0000-0000-000000000002"),
            basePayKind: "fixedPerShift",
            rateIDs: [try uuid("52000000-0000-0000-0000-000000000002")],
            into: store.stack.viewContext
        )
        try store.stack.viewContext.save()

        try LegacyWorkTypeBackfill.run(in: store.stack.viewContext)

        let workTypes = try fetchWorkTypes(in: store.stack.viewContext)
        #expect(workTypes.count == 2)

        let firstWorkType = try #require(workTypes.first { $0.id == first.job.id })
        let secondWorkType = try #require(workTypes.first { $0.id == second.job.id })
        #expect(firstWorkType.basePayKind == "hourly")
        #expect(secondWorkType.basePayKind == "fixedPerShift")
        #expect(firstWorkType.job.objectID == first.job.objectID)
        #expect(secondWorkType.job.objectID == second.job.objectID)
        #expect(first.payRates.allSatisfy { $0.workType?.objectID == firstWorkType.objectID })
        #expect(second.payRates.allSatisfy { $0.workType?.objectID == secondWorkType.objectID })
        #expect(first.payRates.allSatisfy { $0.workType?.objectID != secondWorkType.objectID })
        #expect(second.payRates.allSatisfy { $0.workType?.objectID != firstWorkType.objectID })
    }

    @Test("Conflict откатывает все несохранённые backfill-изменения")
    @MainActor
    func conflictRollsBackTransaction() async throws {
        let store = try await makeEmptyStore()
        defer { removeStore(store) }

        let conflictingJobID = try uuid("61000000-0000-0000-0000-000000000002")
        let valid = try insertJob(
            id: try uuid("61000000-0000-0000-0000-000000000001"),
            basePayKind: "hourly",
            rateIDs: [try uuid("62000000-0000-0000-0000-000000000001")],
            into: store.stack.viewContext
        )
        let conflicting = try insertJob(
            id: conflictingJobID,
            basePayKind: "fixedPerShift",
            rateIDs: [try uuid("62000000-0000-0000-0000-000000000002")],
            into: store.stack.viewContext
        )
        _ = try insertWorkType(
            id: conflicting.job.id,
            basePayKind: "hourly",
            job: conflicting.job,
            into: store.stack.viewContext
        )
        try store.stack.viewContext.save()

        do {
            try LegacyWorkTypeBackfill.run(in: store.stack.viewContext)
            Issue.record("Conflicting compensation basis был принят")
        } catch let LegacyWorkTypeBackfillError.invariantViolation(
            .incompatibleBasePayKind(jobID, expected, actual)
        ) {
            #expect(jobID == conflictingJobID)
            #expect(expected == "fixedPerShift")
            #expect(actual == "hourly")
        } catch {
            Issue.record("Backfill вернул неверную typed error: \(error)")
        }

        let workTypes = try fetchWorkTypes(in: store.stack.viewContext)
        #expect(workTypes.count == 1)
        #expect(workTypes.first?.id == conflictingJobID)
        #expect(valid.job.workTypes?.count == 0)
        #expect(valid.payRates.allSatisfy { $0.workType == nil })
        #expect(FileManager.default.fileExists(atPath: store.storeURL.path))

        try close(store.stack)
        do {
            _ = try await CoreDataStack.load(storeURL: store.storeURL)
            Issue.record("CoreDataStack вернул stack после backfill conflict")
        } catch let CoreDataStackError.legacyWorkTypeBackfillFailed(
            .invariantViolation(.incompatibleBasePayKind(jobID, expected, actual))
        ) {
            #expect(jobID == conflictingJobID)
            #expect(expected == "fixedPerShift")
            #expect(actual == "hourly")
        } catch {
            Issue.record("CoreDataStack вернул неверную typed error: \(error)")
        }
        #expect(FileManager.default.fileExists(atPath: store.storeURL.path))
    }

    private func verifyBackfilledGraph(
        in context: NSManagedObjectContext,
        expectedLegacyGraph: LegacyGraphSnapshot,
        fixture: LegacyCoreDataStoreFixture.Store
    ) throws -> UUID {
        let actualLegacyGraph = try Self.legacySnapshot(in: context)
        #expect(actualLegacyGraph == expectedLegacyGraph)

        let jobs = try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
        let payRates = try context.fetch(NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity"))
        let workTypes = try fetchWorkTypes(in: context)
        let job = try #require(jobs.first)
        let workType = try #require(workTypes.first)

        #expect(jobs.count == 1)
        #expect(workTypes.count == 1)
        #expect(workType.id == fixture.identifiers.job)
        #expect(workType.id == job.id)
        #expect(workType.job.objectID == job.objectID)
        #expect(job.workTypes?.count == 1)
        #expect(
            Set(workType.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set(payRates.map(\.id))
        )
        #expect(payRates.allSatisfy { $0.job.objectID == job.objectID })
        #expect(payRates.allSatisfy { $0.workType?.objectID == workType.objectID })
        #expect(Dictionary(uniqueKeysWithValues: payRates.map { ($0.id, $0.amount.decimalValue) }) == [
            fixture.identifiers.initialPayRate: try decimal("1234.56"),
            fixture.identifiers.earlierPayRate: try decimal("1299.875"),
            fixture.identifiers.laterPayRate: try decimal("1375.125")
        ])

        return workType.id
    }

    @MainActor
    private func verifyStorageCompatibility(
        stack: CoreDataStack,
        fixture: LegacyCoreDataStoreFixture.Store,
        expectedBasis: BasePayBasis
    ) throws {
        let job = try #require(try JobStorage(stack: stack).load())
        let workType = try #require(job.soleWorkType)
        let shifts = try ShiftStorage(stack: stack).loadAll()

        #expect(job.id == fixture.identifiers.job)
        #expect(workType.id == job.id)
        #expect(workType.basePayBasis == expectedBasis)
        #expect(Set(workType.payRates.map(\.id)) == [
            fixture.identifiers.initialPayRate,
            fixture.identifiers.earlierPayRate,
            fixture.identifiers.laterPayRate
        ])
        #expect(Set(shifts.map(\.id)) == [
            fixture.identifiers.sameDayShift,
            fixture.identifiers.shiftWithBreak,
            fixture.identifiers.overnightShift
        ])
    }

    private static func legacySnapshot(
        in context: NSManagedObjectContext
    ) throws -> LegacyGraphSnapshot {
        let jobs = try fetch(entityName: "JobEntity", in: context)
        let payRates = try fetch(entityName: "PayRateEntity", in: context)
        let shifts = try fetch(entityName: "ShiftEntity", in: context)
        let job = try #require(jobs.first)
        let jobPayRates = try #require(job.value(forKey: "payRates") as? NSSet)
        let jobShifts = try #require(job.value(forKey: "shifts") as? NSSet)

        #expect(jobs.count == 1)

        let rateSnapshots = try payRates.map { payRate in
            let relatedJob = try #require(payRate.value(forKey: "job") as? NSManagedObject)
            return PayRateSnapshot(
                id: try requiredUUID(payRate, key: "id"),
                amount: try #require(
                    payRate.value(forKey: "amount") as? NSDecimalNumber
                ).decimalValue,
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

        return LegacyGraphSnapshot(
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
            payRates: rateSnapshots,
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

    private struct EmptyStore {
        let stack: CoreDataStack
        let storeURL: URL
    }

    private struct InsertedJob {
        let job: JobEntity
        let payRates: [PayRateEntity]
    }

    @MainActor
    private func makeEmptyStore() async throws -> EmptyStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerBackfillTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("ShiftLedger.sqlite")
        return EmptyStore(
            stack: try await CoreDataStack.load(storeURL: storeURL),
            storeURL: storeURL
        )
    }

    private func insertJob(
        id: UUID,
        basePayKind: String?,
        rateIDs: [UUID],
        into context: NSManagedObjectContext
    ) throws -> InsertedJob {
        let jobDescription = try #require(
            NSEntityDescription.entity(forEntityName: "JobEntity", in: context)
        )
        let payRateDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context)
        )
        let job = JobEntity(entity: jobDescription, insertInto: context)
        job.id = id
        job.currencyCode = "SEK"
        job.timeZoneIdentifier = "Europe/Stockholm"
        job.basePayKind = basePayKind
        job.payPeriodKind = "perShift"
        job.payPeriodAnchorDate = nil
        job.createdAt = Date(timeIntervalSinceReferenceDate: 900_000)

        let payRates = rateIDs.enumerated().map { index, rateID in
            let payRate = PayRateEntity(entity: payRateDescription, insertInto: context)
            payRate.id = rateID
            payRate.amount = NSDecimalNumber(decimal: Decimal(100 + index))
            payRate.effectiveFrom = index == 0 ? nil : Date(timeIntervalSinceReferenceDate: 910_000)
            payRate.job = job
            return payRate
        }

        return InsertedJob(job: job, payRates: payRates)
    }

    private func insertWorkType(
        id: UUID,
        basePayKind: String,
        job: JobEntity,
        into context: NSManagedObjectContext
    ) throws -> WorkTypeEntity {
        let description = try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: context)
        )
        let workType = WorkTypeEntity(entity: description, insertInto: context)
        workType.id = id
        workType.basePayKind = basePayKind
        workType.job = job
        return workType
    }

    private func fetchWorkTypes(
        in context: NSManagedObjectContext
    ) throws -> [WorkTypeEntity] {
        try context.fetch(NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity"))
    }

    @MainActor
    private func close(_ stacks: [CoreDataStack]) {
        for stack in stacks {
            do {
                try close(stack)
            } catch {
                Issue.record(error)
            }
        }
    }

    @MainActor
    private func close(_ stack: CoreDataStack) throws {
        let context = stack.viewContext
        context.reset()
        let coordinator = try #require(context.persistentStoreCoordinator)
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    private func removeFixture(_ fixture: LegacyCoreDataStoreFixture.Store) {
        do {
            try fixture.remove()
        } catch {
            Issue.record(error)
        }
    }

    @MainActor
    private func removeStore(_ store: EmptyStore) {
        do {
            try close(store.stack)
            try FileManager.default.removeItem(at: store.storeURL.deletingLastPathComponent())
        } catch {
            Issue.record(error)
        }
    }

    private func uuid(_ value: String) throws -> UUID {
        try #require(UUID(uuidString: value))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}
