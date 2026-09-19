import CoreData
import Foundation
import Testing
@testable import ShiftLedger

struct LegacyShiftWorkTypeBackfillTests {
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

        var domainBasis: BasePayBasis {
            switch self {
            case .hourlyWeekly: .hourly
            case .fixedPerShift: .fixedPerShift
            }
        }
    }

    struct LegacyJobSnapshot: Equatable, Sendable {
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

    struct LegacyPayRateSnapshot: Equatable, Sendable {
        let id: UUID
        let amount: Decimal
        let effectiveFrom: Date?
        let jobID: UUID
    }

    struct LegacyShiftSnapshot: Equatable, Sendable {
        let id: UUID
        let start: Date
        let end: Date
        let unpaidBreakStart: Date?
        let unpaidBreakEnd: Date?
        let jobID: UUID
    }

    struct LegacyStoreSnapshot: Equatable, Sendable {
        let job: LegacyJobSnapshot
        let payRates: [LegacyPayRateSnapshot]
        let shifts: [LegacyShiftSnapshot]
    }

    struct CanonicalShiftGraphSnapshot: Equatable, Sendable {
        let workTypeIDs: Set<UUID>
        let shiftWorkTypeIDs: [UUID: UUID]
        let workTypeShiftIDs: [UUID: Set<UUID>]
    }

    @Test(
        "Production V1→V3 backfill связывает Shift с default WorkType и переживает reopen",
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
            do {
                try fixture.remove()
            } catch {
                Issue.record(error)
            }
        }

        let before = try fixture.inspect { context in
            try Self.legacySnapshot(in: context)
        }

        let firstStack = try await CoreDataStack.load(storeURL: fixture.storeURL)
        stacks.append(firstStack)
        let firstGraph = try verifyProductionGraph(
            stack: firstStack,
            fixture: fixture,
            expectedLegacy: before,
            expectedBasis: variant.domainBasis
        )

        try close(firstStack)

        let reopenedStack = try await CoreDataStack.load(storeURL: fixture.storeURL)
        stacks.append(reopenedStack)
        let reopenedGraph = try verifyProductionGraph(
            stack: reopenedStack,
            fixture: fixture,
            expectedLegacy: before,
            expectedBasis: variant.domainBasis
        )

        #expect(reopenedGraph == firstGraph)
        #expect(reopenedStack.viewContext.hasChanges == false)
    }

    @Test("Partial Shift backfill дополняет nil-связь и второй запуск является no-op")
    @MainActor
    func completesPartialState() async throws {
        let store = try await makeExplicitV3Store()
        defer { removeStore(store) }

        let graph = try insertCanonicalJob(
            id: try uuid("41000000-0000-0000-0000-000000000001"),
            into: store.container.viewContext
        )
        let first = try insertShift(
            id: try uuid("43000000-0000-0000-0000-000000000001"),
            job: graph.job,
            workType: graph.workType,
            startOffset: 100,
            into: store.container.viewContext
        )
        let second = try insertShift(
            id: try uuid("43000000-0000-0000-0000-000000000002"),
            job: graph.job,
            workType: nil,
            startOffset: 200,
            into: store.container.viewContext
        )
        let originalDates = [first.id: (first.start, first.end), second.id: (second.start, second.end)]
        try store.container.viewContext.save()

        try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)

        #expect(first.workType?.objectID == graph.workType.objectID)
        #expect(second.workType?.objectID == graph.workType.objectID)
        #expect(first.job?.objectID == graph.job.objectID)
        #expect(second.job?.objectID == graph.job.objectID)
        #expect(first.start == originalDates[first.id]?.0)
        #expect(first.end == originalDates[first.id]?.1)
        #expect(second.start == originalDates[second.id]?.0)
        #expect(second.end == originalDates[second.id]?.1)
        #expect(try fetchWorkTypes(in: store.container.viewContext).count == 1)

        try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)
        #expect(store.container.viewContext.hasChanges == false)
    }

    @Test("Shift backfill не смешивает Jobs")
    @MainActor
    func backfillsMultipleJobsWithoutCrossLinking() async throws {
        let store = try await makeExplicitV3Store()
        defer { removeStore(store) }

        let first = try insertCanonicalJob(
            id: try uuid("51000000-0000-0000-0000-000000000001"),
            into: store.container.viewContext
        )
        let second = try insertCanonicalJob(
            id: try uuid("51000000-0000-0000-0000-000000000002"),
            into: store.container.viewContext
        )
        let firstShift = try insertShift(
            id: try uuid("53000000-0000-0000-0000-000000000001"),
            job: first.job,
            workType: nil,
            startOffset: 300,
            into: store.container.viewContext
        )
        let secondShift = try insertShift(
            id: try uuid("53000000-0000-0000-0000-000000000002"),
            job: second.job,
            workType: nil,
            startOffset: 400,
            into: store.container.viewContext
        )
        try store.container.viewContext.save()

        try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)

        #expect(firstShift.workType?.objectID == first.workType.objectID)
        #expect(secondShift.workType?.objectID == second.workType.objectID)
        #expect(firstShift.workType?.objectID != second.workType.objectID)
        #expect(secondShift.workType?.objectID != first.workType.objectID)
    }

    @Test("Поздний conflict откатывает более раннее Shift-присваивание")
    @MainActor
    func conflictRollsBackTransaction() async throws {
        let store = try await makeExplicitV3Store()
        defer { removeStore(store) }

        let first = try insertCanonicalJob(
            id: try uuid("61000000-0000-0000-0000-000000000001"),
            into: store.container.viewContext
        )
        let second = try insertCanonicalJob(
            id: try uuid("61000000-0000-0000-0000-000000000002"),
            into: store.container.viewContext
        )
        let validShift = try insertShift(
            id: try uuid("63000000-0000-0000-0000-000000000001"),
            job: first.job,
            workType: nil,
            startOffset: 500,
            into: store.container.viewContext
        )
        let conflictingShiftID = try uuid("63000000-0000-0000-0000-000000000002")
        let conflictingShift = try insertShift(
            id: conflictingShiftID,
            job: first.job,
            workType: second.workType,
            startOffset: 600,
            into: store.container.viewContext
        )
        try store.container.viewContext.save()

        do {
            try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)
            Issue.record("Conflicting Shift WorkType был принят")
        } catch let LegacyShiftWorkTypeBackfillError.invariantViolation(
            .shiftAssignedToDifferentWorkType(
                shiftID,
                jobID,
                expectedWorkTypeID,
                actualWorkTypeID
            )
        ) {
            #expect(shiftID == conflictingShiftID)
            #expect(jobID == first.job.id)
            #expect(expectedWorkTypeID == first.workType.id)
            #expect(actualWorkTypeID == second.workType.id)
        } catch {
            Issue.record("Backfill вернул неверную typed error: \(error)")
        }

        #expect(validShift.workType == nil)
        #expect(conflictingShift.workType?.objectID == second.workType.objectID)
        #expect(try fetchShifts(in: store.container.viewContext).count == 2)
        #expect(try fetchWorkTypes(in: store.container.viewContext).count == 2)
        #expect(FileManager.default.fileExists(atPath: store.storeURL.path))

        let validShiftID = validShift.id
        let secondWorkTypeID = second.workType.id
        try close(store.container)
        let reopened = try await loadExplicitV3Container(storeURL: store.storeURL)
        let reopenedShifts = try fetchShifts(in: reopened.viewContext)
        let reopenedValid = try #require(reopenedShifts.first { $0.id == validShiftID })
        let reopenedConflict = try #require(reopenedShifts.first { $0.id == conflictingShiftID })
        #expect(reopenedValid.workType == nil)
        #expect(reopenedConflict.workType?.id == secondWorkTypeID)
        try close(reopened)
    }

    @Test("Shift без default WorkType отклоняется без создания замены")
    @MainActor
    func rejectsMissingDefaultWorkType() async throws {
        let store = try await makeExplicitV3Store()
        defer { removeStore(store) }

        let jobID = try uuid("71000000-0000-0000-0000-000000000001")
        let graph = try insertLegacyJob(id: jobID, into: store.container.viewContext)
        let shiftID = try uuid("73000000-0000-0000-0000-000000000001")
        let shift = try insertShift(
            id: shiftID,
            job: graph.job,
            workType: nil,
            startOffset: 700,
            into: store.container.viewContext
        )
        try store.container.viewContext.save()

        do {
            try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)
            Issue.record("Missing default WorkType был создан неявно")
        } catch let LegacyShiftWorkTypeBackfillError.invariantViolation(
            .missingDefaultWorkType(actualShiftID, actualJobID)
        ) {
            #expect(actualShiftID == shiftID)
            #expect(actualJobID == jobID)
        } catch {
            Issue.record("Backfill вернул неверную typed error: \(error)")
        }

        #expect(shift.workType == nil)
        #expect(try fetchWorkTypes(in: store.container.viewContext).isEmpty)
    }

    @Test("Shift с другим WorkType отклоняется и не перемещается")
    @MainActor
    func rejectsWrongExistingWorkType() async throws {
        let store = try await makeExplicitV3Store()
        defer { removeStore(store) }

        let graph = try insertCanonicalJob(
            id: try uuid("81000000-0000-0000-0000-000000000001"),
            into: store.container.viewContext
        )
        let alternate = try insertWorkType(
            id: try uuid("82000000-0000-0000-0000-000000000001"),
            job: graph.job,
            into: store.container.viewContext
        )
        let shiftID = try uuid("83000000-0000-0000-0000-000000000001")
        let shift = try insertShift(
            id: shiftID,
            job: graph.job,
            workType: alternate,
            startOffset: 800,
            into: store.container.viewContext
        )
        try store.container.viewContext.save()

        do {
            try LegacyShiftWorkTypeBackfill.run(in: store.container.viewContext)
            Issue.record("Wrong WorkType был автоматически заменён")
        } catch let LegacyShiftWorkTypeBackfillError.invariantViolation(
            .shiftAssignedToDifferentWorkType(
                actualShiftID,
                actualJobID,
                expectedWorkTypeID,
                actualWorkTypeID
            )
        ) {
            #expect(actualShiftID == shiftID)
            #expect(actualJobID == graph.job.id)
            #expect(expectedWorkTypeID == graph.workType.id)
            #expect(actualWorkTypeID == alternate.id)
        } catch {
            Issue.record("Backfill вернул неверную typed error: \(error)")
        }

        #expect(shift.workType?.objectID == alternate.objectID)
    }

    @MainActor
    private func verifyProductionGraph(
        stack: CoreDataStack,
        fixture: LegacyCoreDataStoreFixture.Store,
        expectedLegacy: LegacyStoreSnapshot,
        expectedBasis: BasePayBasis
    ) throws -> CanonicalShiftGraphSnapshot {
        let context = stack.viewContext
        #expect(try Self.legacySnapshot(in: context) == expectedLegacy)

        let jobs = try context.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
        let workTypes = try fetchWorkTypes(in: context)
        let payRates = try context.fetch(NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity"))
        let shifts = try fetchShifts(in: context)
        let job = try #require(jobs.first)
        let workType = try #require(workTypes.first)

        #expect(jobs.count == 1)
        #expect(workTypes.count == 1)
        #expect(payRates.count == 3)
        #expect(shifts.count == 3)
        #expect(workType.id == job.id)
        #expect(workType.id == fixture.identifiers.job)
        #expect(workType.job.objectID == job.objectID)
        #expect(shifts.allSatisfy { $0.job?.objectID == job.objectID })
        #expect(shifts.allSatisfy { $0.workType?.objectID == workType.objectID })
        #expect(
            Set(workType.shifts?.compactMap { ($0 as? ShiftEntity)?.id } ?? [])
                == Set(shifts.map(\.id))
        )
        #expect(Dictionary(uniqueKeysWithValues: payRates.map { ($0.id, $0.amount.decimalValue) }) == [
            fixture.identifiers.initialPayRate: try decimal("1234.56"),
            fixture.identifiers.earlierPayRate: try decimal("1299.875"),
            fixture.identifiers.laterPayRate: try decimal("1375.125")
        ])

        let domainJob = try #require(try JobStorage(stack: stack).load())
        #expect(domainJob.id == fixture.identifiers.job)
        #expect(domainJob.workTypeID == domainJob.id)
        #expect(domainJob.basePayBasis == expectedBasis)
        #expect(Set(domainJob.payRates.map(\.id)) == expectedLegacy.job.payRateIDs)

        let domainShifts = try ShiftStorage(stack: stack).loadAll()
        let domainSnapshots = domainShifts.map {
            LegacyShiftSnapshot(
                id: $0.id,
                start: $0.start,
                end: $0.end,
                unpaidBreakStart: $0.unpaidBreak?.start,
                unpaidBreakEnd: $0.unpaidBreak?.end,
                jobID: job.id
            )
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(domainSnapshots == expectedLegacy.shifts)

        return CanonicalShiftGraphSnapshot(
            workTypeIDs: Set(workTypes.map(\.id)),
            shiftWorkTypeIDs: Dictionary(
                uniqueKeysWithValues: try shifts.map { shift in
                    (shift.id, try #require(shift.workType).id)
                }
            ),
            workTypeShiftIDs: [
                workType.id: Set(workType.shifts?.compactMap { ($0 as? ShiftEntity)?.id } ?? [])
            ]
        )
    }

    private static func legacySnapshot(
        in context: NSManagedObjectContext
    ) throws -> LegacyStoreSnapshot {
        let jobs = try fetch(entityName: "JobEntity", in: context)
        let payRates = try fetch(entityName: "PayRateEntity", in: context)
        let shifts = try fetch(entityName: "ShiftEntity", in: context)
        let job = try #require(jobs.first)
        let jobPayRates = try #require(job.value(forKey: "payRates") as? NSSet)
        let jobShifts = try #require(job.value(forKey: "shifts") as? NSSet)

        #expect(jobs.count == 1)

        return LegacyStoreSnapshot(
            job: LegacyJobSnapshot(
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
            payRates: try payRates.map { payRate in
                let relatedJob = try #require(payRate.value(forKey: "job") as? NSManagedObject)
                return LegacyPayRateSnapshot(
                    id: try requiredUUID(payRate, key: "id"),
                    amount: try #require(
                        payRate.value(forKey: "amount") as? NSDecimalNumber
                    ).decimalValue,
                    effectiveFrom: payRate.value(forKey: "effectiveFrom") as? Date,
                    jobID: try requiredUUID(relatedJob, key: "id")
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString },
            shifts: try shifts.map { shift in
                let relatedJob = try #require(shift.value(forKey: "job") as? NSManagedObject)
                return LegacyShiftSnapshot(
                    id: try requiredUUID(shift, key: "id"),
                    start: try requiredDate(shift, key: "start"),
                    end: try requiredDate(shift, key: "end"),
                    unpaidBreakStart: shift.value(forKey: "unpaidBreakStart") as? Date,
                    unpaidBreakEnd: shift.value(forKey: "unpaidBreakEnd") as? Date,
                    jobID: try requiredUUID(relatedJob, key: "id")
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        )
    }

    private struct ExplicitStore {
        let container: NSPersistentContainer
        let storeURL: URL
        let directoryURL: URL
    }

    private struct InsertedJob {
        let job: JobEntity
        let payRate: PayRateEntity
    }

    private struct CanonicalJob {
        let job: JobEntity
        let workType: WorkTypeEntity
        let payRate: PayRateEntity
    }

    @MainActor
    private func makeExplicitV3Store() async throws -> ExplicitStore {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyShiftWorkTypeBackfillTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let storeURL = directoryURL.appendingPathComponent("ShiftLedger.sqlite")
        return ExplicitStore(
            container: try await loadExplicitV3Container(storeURL: storeURL),
            storeURL: storeURL,
            directoryURL: directoryURL
        )
    }

    @MainActor
    private func loadExplicitV3Container(
        storeURL: URL
    ) async throws -> NSPersistentContainer {
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

    private func insertCanonicalJob(
        id: UUID,
        into context: NSManagedObjectContext
    ) throws -> CanonicalJob {
        let legacy = try insertLegacyJob(id: id, into: context)
        let workType = try insertWorkType(id: id, job: legacy.job, into: context)
        legacy.payRate.workType = workType
        return CanonicalJob(job: legacy.job, workType: workType, payRate: legacy.payRate)
    }

    private func insertLegacyJob(
        id: UUID,
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
        job.basePayKind = StoredBasePayKind.hourly.rawValue
        job.payPeriodKind = "perShift"
        job.payPeriodAnchorDate = nil
        job.createdAt = Date(timeIntervalSinceReferenceDate: 900_000)

        let payRate = PayRateEntity(entity: payRateDescription, insertInto: context)
        payRate.id = id
        payRate.amount = NSDecimalNumber(string: "1234.56")
        payRate.effectiveFrom = nil
        payRate.job = job

        return InsertedJob(job: job, payRate: payRate)
    }

    private func insertWorkType(
        id: UUID,
        job: JobEntity,
        into context: NSManagedObjectContext
    ) throws -> WorkTypeEntity {
        let description = try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: context)
        )
        let workType = WorkTypeEntity(entity: description, insertInto: context)
        workType.id = id
        workType.basePayKind = StoredBasePayKind.hourly.rawValue
        workType.job = job
        return workType
    }

    private func insertShift(
        id: UUID,
        job: JobEntity,
        workType: WorkTypeEntity?,
        startOffset: TimeInterval,
        into context: NSManagedObjectContext
    ) throws -> ShiftEntity {
        let description = try #require(
            NSEntityDescription.entity(forEntityName: "ShiftEntity", in: context)
        )
        let shift = ShiftEntity(entity: description, insertInto: context)
        shift.id = id
        shift.start = Date(timeIntervalSinceReferenceDate: 1_000_000 + startOffset)
        shift.end = Date(timeIntervalSinceReferenceDate: 1_003_600 + startOffset)
        shift.unpaidBreakStart = nil
        shift.unpaidBreakEnd = nil
        shift.job = job
        shift.workType = workType
        return shift
    }

    private static func fetch(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
    }

    private func fetchWorkTypes(
        in context: NSManagedObjectContext
    ) throws -> [WorkTypeEntity] {
        try context.fetch(NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity"))
    }

    private func fetchShifts(
        in context: NSManagedObjectContext
    ) throws -> [ShiftEntity] {
        try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
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

    @MainActor
    private func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    @MainActor
    private func removeStore(_ store: ExplicitStore) {
        do {
            try close(store.container)
            guard FileManager.default.fileExists(atPath: store.directoryURL.path) else {
                return
            }
            try FileManager.default.removeItem(at: store.directoryURL)
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
