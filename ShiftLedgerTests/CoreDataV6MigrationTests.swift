import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct CoreDataV6MigrationTests {
    enum Cycle: CaseIterable {
        case perShift, weekly, biweekly, calendarMonthly

        var value: PayCalculationCycle {
            get throws {
                switch self {
                case .perShift: .perShift
                case .weekly: .scheduled(.weekly(anchorDate: try LocalDate(year: 2026, month: 1, day: 5)))
                case .biweekly: .scheduled(.biweekly(anchorDate: try LocalDate(year: 2026, month: 1, day: 5)))
                case .calendarMonthly: .scheduled(.calendarMonthly)
                }
            }
        }
    }

    private enum StoredValue: Equatable {
        case null, uuid(UUID), string(String), date(Date), decimal(Decimal), boolean(Bool)
        case relatedIDs(Set<UUID>)
    }

    private struct Record: Equatable {
        let values: [String: StoredValue]
    }

    private struct Fixture {
        let job: Job
        let shifts: [Shift]
    }

    @Test("Compiled current model is V6 and the V5 mapping is inferable")
    func compiledModelIsV6() throws {
        let v5 = try model(named: "ShiftLedgerV5")
        let v6 = try model(named: "ShiftLedgerV6")
        let current = try #require(NSManagedObjectModel(contentsOf: modelPackageURL()))
        #expect(current.entityVersionHashesByName == v6.entityVersionHashesByName)
        let job = try #require(current.entitiesByName["JobEntity"])
        let name = try #require(job.attributesByName["name"])
        let archived = try #require(job.attributesByName["isArchived"])
        #expect(name.attributeType == .stringAttributeType)
        #expect(name.isOptional)
        #expect(name.defaultValue == nil)
        #expect(archived.attributeType == .booleanAttributeType)
        #expect(archived.isOptional == false)
        #expect((archived.defaultValue as? NSNumber)?.boolValue == false)
        #expect(v5.entitiesByName["JobEntity"]?.attributesByName["name"] == nil)
        #expect(v5.entitiesByName["JobEntity"]?.attributesByName["isArchived"] == nil)
        _ = try NSMappingModel.inferredMappingModel(forSourceModel: v5, destinationModel: v6)
    }

    @Test("Populated V5 SQLite preserves its complete graph and exact payroll in V6 and after reopen",
          arguments: Cycle.allCases)
    func migratesPopulatedV5AndReopens(_ cycle: Cycle) async throws {
        let storeURL = try temporaryStoreURL()
        var coordinators: [NSPersistentStoreCoordinator] = []
        defer { cleanup(coordinators, storeURL: storeURL) }
        let fixture = try makeFixture(cycle: cycle)
        let v5 = try model(named: "ShiftLedgerV5")
        let container = try await loadV5(model: v5, storeURL: storeURL)
        coordinators.append(container.persistentStoreCoordinator)
        try seed(fixture, in: container.viewContext)
        let before = try snapshot(in: container.viewContext)
        let expectedAmounts = try fixture.shifts.map { try fixture.job.basePay(for: $0) }
        #expect(expectedAmounts == [try decimal("200.25"), try decimal("219.40625"), try decimal("2.008")])
        let expectedGross = try fixture.shifts.map {
            try fixture.job.expectedGross(for: fixture.job.payCalculationPeriod(for: $0), from: fixture.shifts)
        }
        container.viewContext.reset()
        try close(container.persistentStoreCoordinator)
        let oldMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL)
        #expect(v5.isConfiguration(withName: nil, compatibleWithStoreMetadata: oldMetadata))
        #expect(try model(named: "ShiftLedgerV6").isConfiguration(
            withName: nil, compatibleWithStoreMetadata: oldMetadata) == false)

        let migrated = try await CoreDataStack.load(storeURL: storeURL)
        let firstCoordinator = try #require(migrated.viewContext.persistentStoreCoordinator)
        coordinators.append(firstCoordinator)
        try verify(migrated, fixture: fixture, before: before,
                   expectedAmounts: expectedAmounts, expectedGross: expectedGross)
        migrated.viewContext.reset()
        try close(firstCoordinator)

        let reopened = try await CoreDataStack.load(storeURL: storeURL)
        coordinators.append(try #require(reopened.viewContext.persistentStoreCoordinator))
        try verify(reopened, fixture: fixture, before: before,
                   expectedAmounts: expectedAmounts, expectedGross: expectedGross)
        let newMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL)
        #expect(try model(named: "ShiftLedgerV6").isConfiguration(
            withName: nil, compatibleWithStoreMetadata: newMetadata))
    }

    @Test("Fresh V6 production single-Job save keeps nil name and false archive state across reopen")
    func freshV6StoreAndReopen() async throws {
        let storeURL = try temporaryStoreURL()
        var coordinators: [NSPersistentStoreCoordinator] = []
        defer { cleanup(coordinators, storeURL: storeURL) }
        let fixture = try makeFixture(cycle: .perShift)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        let firstCoordinator = try #require(stack.viewContext.persistentStoreCoordinator)
        coordinators.append(firstCoordinator)
        try JobStorage(stack: stack).save(fixture.job)
        try verifyJobMetadata(stack, expectedJob: fixture.job)
        let before = try snapshot(in: stack.viewContext)
        stack.viewContext.reset()
        try close(firstCoordinator)
        let reopened = try await CoreDataStack.load(storeURL: storeURL)
        coordinators.append(try #require(reopened.viewContext.persistentStoreCoordinator))
        try verifyJobMetadata(reopened, expectedJob: fixture.job)
        #expect(try snapshot(in: reopened.viewContext) == before)
        #expect(try ShiftStorage(stack: reopened).loadAll().isEmpty)
        #expect(reopened.viewContext.hasChanges == false)
    }

    private func verify(
        _ stack: CoreDataStack, fixture: Fixture,
        before: [String: [UUID: Record]], expectedAmounts: [Decimal], expectedGross: [Decimal]
    ) throws {
        try verifyJobMetadata(stack, expectedJob: fixture.job)
        #expect(try snapshot(in: stack.viewContext) == before)
        let job = try #require(try JobStorage(stack: stack).load())
        let shifts = try ShiftStorage(stack: stack).loadAll()
        #expect(shifts == fixture.shifts)
        #expect(try shifts.map { try job.basePay(for: $0) } == expectedAmounts)
        #expect(try shifts.map {
            try job.expectedGross(for: job.payCalculationPeriod(for: $0), from: shifts)
        } == expectedGross)
        #expect(stack.viewContext.hasChanges == false)
    }

    private func verifyJobMetadata(_ stack: CoreDataStack, expectedJob: Job) throws {
        let jobs = try stack.viewContext.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
        #expect(jobs.count == 1)
        let entity = try #require(jobs.first)
        #expect(entity.name == nil)
        #expect(entity.isArchived == false)
        #expect(try JobStorage(stack: stack).load() == expectedJob)
        let current = try #require(stack.viewContext.persistentStoreCoordinator?.managedObjectModel)
        let v6 = try model(named: "ShiftLedgerV6")
        #expect(current.entityVersionHashesByName == v6.entityVersionHashesByName)
    }

    // Read every historical attribute and both sides of every relationship as value data.
    // Only the two additive Job attributes are checked separately from the V5 snapshot.
    private func snapshot(in context: NSManagedObjectContext) throws -> [String: [UUID: Record]] {
        var result: [String: [UUID: Record]] = [:]
        for entityName in ["JobEntity", "WorkTypeEntity", "PayRateEntity", "ShiftEntity"] {
            let objects = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
            var records: [UUID: Record] = [:]
            for object in objects {
                let id = try #require(object.value(forKey: "id") as? UUID)
                var values: [String: StoredValue] = [:]
                for (key, attribute) in object.entity.attributesByName {
                    if entityName == "JobEntity", key == "name" || key == "isArchived" { continue }
                    guard let raw = object.value(forKey: key) else {
                        values[key] = .null
                        continue
                    }
                    switch attribute.attributeType {
                    case .UUIDAttributeType: values[key] = .uuid(try #require(raw as? UUID))
                    case .stringAttributeType: values[key] = .string(try #require(raw as? String))
                    case .dateAttributeType: values[key] = .date(try #require(raw as? Date))
                    case .decimalAttributeType: values[key] = .decimal(try #require(raw as? NSDecimalNumber).decimalValue)
                    case .booleanAttributeType: values[key] = .boolean(try #require(raw as? NSNumber).boolValue)
                    default: throw SnapshotError.unsupportedAttribute(key)
                    }
                }
                for (key, relationship) in object.entity.relationshipsByName {
                    if relationship.isToMany {
                        let related = try #require(object.value(forKey: key) as? NSSet)
                        values[key] = .relatedIDs(Set(try related.map {
                            let relatedObject = try #require($0 as? NSManagedObject)
                            return try #require(relatedObject.value(forKey: "id") as? UUID)
                        }))
                    } else if let related = object.value(forKey: key) as? NSManagedObject {
                        values[key] = .uuid(try #require(related.value(forKey: "id") as? UUID))
                    } else { values[key] = .null }
                }
                #expect(records[id] == nil)
                records[id] = Record(values: values)
            }
            #expect(records.count == objects.count)
            result[entityName] = records
        }
        return result
    }

    private enum SnapshotError: Error { case unsupportedAttribute(String) }

    private func makeFixture(cycle: Cycle) throws -> Fixture {
        let date = try LocalDate(year: 2026, month: 2, day: 1)
        let hourly = WorkType(id: id(2), name: "Lectures", basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(id: id(4), amount: decimal("100.125"), effectiveFrom: nil),
                try PayRate(id: id(5), amount: decimal("125.375"), effectiveFrom: date)
            ]))
        let fixed = WorkType(id: id(3), name: "Workshop", basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(id: id(6), amount: decimal("1.004"), effectiveFrom: nil),
                try PayRate(id: id(7), amount: decimal("2.008"), effectiveFrom: date)
            ]), isArchived: true)
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let earlier = try LocalDate(year: 2026, month: 1, day: 31).startOfDay(in: timeZone).addingTimeInterval(9 * 3600)
        let later = try date.startOfDay(in: timeZone).addingTimeInterval(9 * 3600)
        return Fixture(job: try Job(id: id(1), currencyCode: "EUR",
            timeZoneIdentifier: timeZone.identifier, payCalculationCycle: cycle.value,
            workTypes: [hourly, fixed], createdAt: Date(timeIntervalSinceReferenceDate: 900_000)),
            shifts: [
                try Shift(id: id(8), workTypeID: hourly.id, start: earlier, end: earlier.addingTimeInterval(7200)),
                try Shift(id: id(9), workTypeID: hourly.id, start: later, end: later.addingTimeInterval(7200),
                    unpaidBreak: UnpaidBreak(start: later.addingTimeInterval(3600), end: later.addingTimeInterval(4500))),
                try Shift(id: id(10), workTypeID: fixed.id, start: later.addingTimeInterval(10800), end: later.addingTimeInterval(14400))
            ])
    }

    private func seed(_ fixture: Fixture, in context: NSManagedObjectContext) throws {
        let job = try insert("JobEntity", in: context)
        job.setValue(fixture.job.id, forKey: "id")
        job.setValue(fixture.job.currencyCode, forKey: "currencyCode")
        job.setValue(fixture.job.timeZoneIdentifier, forKey: "timeZoneIdentifier")
        job.setValue(fixture.job.createdAt, forKey: "createdAt")
        job.setValue(nil, forKey: "basePayKind")
        let timeZone = try #require(TimeZone(identifier: fixture.job.timeZoneIdentifier))
        switch fixture.job.payCalculationCycle {
        case .perShift: job.setValue("perShift", forKey: "payPeriodKind")
        case let .scheduled(schedule):
            switch schedule {
            case let .weekly(anchor):
                job.setValue("weekly", forKey: "payPeriodKind")
                job.setValue(try anchor.startOfDay(in: timeZone), forKey: "payPeriodAnchorDate")
            case let .biweekly(anchor):
                job.setValue("biweekly", forKey: "payPeriodKind")
                job.setValue(try anchor.startOfDay(in: timeZone), forKey: "payPeriodAnchorDate")
            case .calendarMonthly: job.setValue("calendarMonthly", forKey: "payPeriodKind")
            }
        }
        var workTypes: [UUID: NSManagedObject] = [:]
        for value in fixture.job.workTypes {
            let workType = try insert("WorkTypeEntity", in: context)
            workType.setValue(value.id, forKey: "id")
            workType.setValue(value.name, forKey: "name")
            workType.setValue(value.basePayBasis == .hourly ? "hourly" : "fixedPerShift", forKey: "basePayKind")
            workType.setValue(value.isArchived, forKey: "isArchived")
            workType.setValue(job, forKey: "job")
            workTypes[value.id] = workType
            for value in value.payRates {
                let rate = try insert("PayRateEntity", in: context)
                rate.setValue(value.id, forKey: "id")
                rate.setValue(NSDecimalNumber(decimal: value.amount), forKey: "amount")
                rate.setValue(try value.effectiveFrom?.startOfDay(in: timeZone), forKey: "effectiveFrom")
                rate.setValue(job, forKey: "job")
                rate.setValue(workType, forKey: "workType")
            }
        }
        for value in fixture.shifts {
            let shift = try insert("ShiftEntity", in: context)
            shift.setValue(value.id, forKey: "id")
            shift.setValue(value.start, forKey: "start")
            shift.setValue(value.end, forKey: "end")
            shift.setValue(value.unpaidBreak?.start, forKey: "unpaidBreakStart")
            shift.setValue(value.unpaidBreak?.end, forKey: "unpaidBreakEnd")
            shift.setValue(job, forKey: "job")
            let workType = try #require(workTypes[value.workTypeID])
            shift.setValue(workType, forKey: "workType")
        }
        try context.save()
    }

    private func id(_ suffix: UInt8) -> UUID {
        UUID(uuid: (0x46, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, suffix))
    }

    private func decimal(_ string: String) throws -> Decimal {
        try #require(Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")))
    }

    private func insert(_ name: String, in context: NSManagedObjectContext) throws -> NSManagedObject {
        let entity = try #require(NSEntityDescription.entity(forEntityName: name, in: context))
        return NSManagedObject(entity: entity, insertInto: context)
    }

    private func modelPackageURL() throws -> URL {
        try #require(Bundle.main.url(forResource: "ShiftLedger", withExtension: "momd"))
    }

    private func model(named name: String) throws -> NSManagedObjectModel {
        let url = try modelPackageURL().appendingPathComponent(name).appendingPathExtension("mom")
        return try #require(NSManagedObjectModel(contentsOf: url))
    }

    private func loadV5(model: NSManagedObjectModel, storeURL: URL) async throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ShiftLedger", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation(isolation: MainActor.shared) { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
        return container
    }

    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShiftLedgerV6Tests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func close(_ coordinator: NSPersistentStoreCoordinator) throws {
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }

    private func cleanup(_ coordinators: [NSPersistentStoreCoordinator], storeURL: URL) {
        do {
            for coordinator in coordinators { try close(coordinator) }
            try FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        } catch { Issue.record(error) }
    }
}
