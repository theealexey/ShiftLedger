import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct PayRateStoreMigrationTests {
    private enum Interrupted: Error { case beforeSourceIntent, before, after }
    private enum ScopedIdentityCase: CaseIterable { case valid, duplicateRate, duplicateWorkType }
    private enum StagedChange: CaseIterable { case rate, shift }
    private enum UninitializedArtifact: CaseIterable { case store, backup, pendingBackup }
    private enum SelectionDamage: CaseIterable { case missingSelector, corruptSelector, missingStore }

    @Test(arguments: Array(1...6))
    func historicalVersionsPreserveRatesShiftsAndPayroll(_ version: Int) async throws {
        let fixed = version.isMultiple(of: 2)
        let fixture = try LegacyCoreDataStoreFixture.make(
            payBasis: fixed ? .fixedPerShift : .hourly, payPeriod: fixed ? .perShift : .weekly
        )
        defer { try? fixture.remove() }
        let original = try makeSource(version: version, fixture: fixture)
        let historical = try await CoreDataStack.load(storeURL: original)
        let selected = try activeURL(historical)
        let loaded = try #require(try JobStorage(stack: historical).load())
        let expectedAmounts = ["1234.56", "1299.875", "1375.125"]
        let rates = try #require(loaded.soleWorkType).payRates
        #expect(loaded.id == fixture.identifiers.job)
        #expect(loaded.soleWorkType?.id == loaded.id)
        #expect(rates.map(\.id) == [fixture.identifiers.initialPayRate, fixture.identifiers.earlierPayRate, fixture.identifiers.laterPayRate])
        #expect(try rates.map { try PayRateDecimalCodec.encode($0.amount) } == expectedAmounts)
        #expect(rates.map(\.effectiveFrom) == [
            nil, try LocalDate(year: 2026, month: 3, day: 1), try LocalDate(year: 2026, month: 7, day: 1)
        ])
        let shifts = try ShiftStorage(stack: historical).loadAll(forJobID: loaded.id)
        #expect(Set(shifts.map(\.id)) == [fixture.identifiers.sameDayShift, fixture.identifiers.shiftWithBreak, fixture.identifiers.overnightShift])
        #expect(shifts.allSatisfy { $0.jobID == loaded.id && $0.workTypeID == loaded.id })
        #expect(shifts.first { $0.id == fixture.identifiers.shiftWithBreak }?.unpaidBreak != nil)
        #expect(shifts.allSatisfy { $0.paidDuration == 28_800 })
        let exactRate = try PayRateDecimalCodec.decode("1375.125")
        let expectedContribution = fixed ? exactRate : exactRate * 8
        #expect(try shifts.map { try loaded.applicablePayRate(for: $0).id } == Array(repeating: fixture.identifiers.laterPayRate, count: 3))
        #expect(try shifts.map { try loaded.basePay(for: $0) } == Array(repeating: expectedContribution, count: 3))
        let selectedPeriod = try loaded.payCalculationPeriod(for: #require(shifts.first))
        #expect(try loaded.expectedGross(for: selectedPeriod, from: shifts) == expectedContribution * (fixed ? 1 : 3))
        try close(historical)

        let reopened = try await CoreDataStack.load(storeURL: original)
        defer { try? close(reopened) }
        #expect(try activeURL(reopened) == selected)
        #expect(try JobStorage(stack: reopened).load() == loaded)
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: loaded.id) == shifts)
        let backup = selected.deletingLastPathComponent().appendingPathComponent("backup/store.sqlite")
        let backupMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: backup
        )
        #expect(try PayRateStoreMigrator.model(version: version).isConfiguration(withName: nil, compatibleWithStoreMetadata: backupMetadata))
    }

    @Test
    func interruptedBeforeAndAfterActivationReusesTheValidatedStore() async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let original = fixture.storeURL
        let workspace = PayRateStoreMigrator.workspace(for: original)
        let staged = workspace.appendingPathComponent("staging/store.sqlite")
        let active = workspace.appendingPathComponent("active/store.sqlite")

        await #expect(throws: Interrupted.before) {
            try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeActivation = stage { throw Interrupted.before }
            }
        }
        let stagedMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: staged)
        #expect(!FileManager.default.fileExists(atPath: active.path))
        let sourceCount = try fixture.inspect { context in
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "JobEntity"))
        }
        #expect(sourceCount == 1)
        await #expect(throws: Interrupted.after) {
            try await PayRateStoreMigrator.resolve(original: original) { stage in
                switch stage {
                case .beforeValidation: Issue.record("Validated staging was migrated again")
                case .afterActivation: throw Interrupted.after
                case .beforeSourceIntent, .beforeActivation: break
                }
            }
        }
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        let activeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: active)
        #expect((stagedMetadata[NSStoreUUIDKey] as? String) == (activeMetadata[NSStoreUUIDKey] as? String))
        let opened = try await PayRateStoreMigrator.resolve(original: original) { _ in
            Issue.record("Previously activated store entered migration")
        }
        #expect(opened == active)
        let stack = try await CoreDataStack.load(storeURL: original)
        defer { try? close(stack) }
        #expect(try JobStorage(stack: stack).load()?.id == fixture.identifiers.job)
    }

    @Test(arguments: ScopedIdentityCase.allCases)
    private func migrationValidatesIdentityWithinItsOwner(_ testCase: ScopedIdentityCase) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let original = fixture.storeURL.deletingLastPathComponent().appendingPathComponent("ScopedV6.sqlite")
        let jobID = UUID()
        let otherJobID = UUID()
        let sharedWorkTypeID = UUID()
        let otherWorkTypeID = UUID()
        let sharedRateID = UUID()
        let shiftIDs = [UUID(), UUID(), UUID()]

        try Self.withStore(at: original, version: 6) { context in
            let start = Date(timeIntervalSince1970: 1_760_000_000)
            let firstJob = try Self.insert(JobEntity.self, named: "JobEntity", in: context)
            let secondJob = try Self.insert(JobEntity.self, named: "JobEntity", in: context)
            for (job, id) in [(firstJob, jobID), (secondJob, otherJobID)] {
                job.id = id
                job.currencyCode = "EUR"
                job.timeZoneIdentifier = "Europe/Stockholm"
                job.payPeriodKind = "perShift"
                job.createdAt = start
            }

            let otherTypeID = testCase == .duplicateWorkType ? sharedWorkTypeID : otherWorkTypeID
            let owners = [(firstJob, sharedWorkTypeID), (firstJob, otherTypeID), (secondJob, sharedWorkTypeID)]
            for (index, owner) in owners.enumerated() {
                let (job, typeID) = owner
                let workType = try Self.insert(WorkTypeEntity.self, named: "WorkTypeEntity", in: context)
                workType.id = typeID
                workType.name = "Work type \(index + 1)"
                workType.basePayKind = "fixedPerShift"
                workType.job = job
                let rate = try Self.insert(PayRateEntity.self, named: "PayRateEntity", in: context)
                rate.id = index == 1 && testCase == .duplicateWorkType ? UUID() : sharedRateID
                rate.amount = NSDecimalNumber(value: (index + 1) * 100)
                rate.job = job
                rate.workType = workType

                let shift = try Self.insert(ShiftEntity.self, named: "ShiftEntity", in: context)
                shift.id = shiftIDs[index]
                shift.start = start.addingTimeInterval(TimeInterval(index * 7200))
                shift.end = shift.start.addingTimeInterval(3600)
                shift.job = job
                shift.workType = workType

                if index == 0, testCase == .duplicateRate {
                    let duplicate = try Self.insert(PayRateEntity.self, named: "PayRateEntity", in: context)
                    duplicate.id = sharedRateID
                    duplicate.amount = NSDecimalNumber(value: 110)
                    duplicate.effectiveFrom = start
                    duplicate.job = job
                    duplicate.workType = workType
                }
            }
            try context.save()
        }

        if testCase != .valid {
            do {
                _ = try await PayRateStoreMigrator.resolve(original: original)
                Issue.record("Duplicate identity in the same scope was activated")
            } catch PayRateStoreMigrationError.validationFailed(let cause) {
                guard case PayRateStoreMigrationError.invalidGraph(let entity) = cause else {
                    Issue.record("Unexpected validation error: \(cause)")
                    return
                }
                #expect(entity == (testCase == .duplicateRate ? "PayRateEntity" : "WorkTypeEntity"))
            }
            #expect(!FileManager.default.fileExists(atPath: PayRateStoreMigrator.workspace(for: original)
                .appendingPathComponent("active").path))
            return
        }

        let migrated = try await CoreDataStack.load(storeURL: original)
        defer { try? close(migrated) }
        let jobs = JobStorage(stack: migrated)
        let shifts = ShiftStorage(stack: migrated)
        let firstJob = try jobs.load(forJobID: jobID)
        let secondJob = try jobs.load(forJobID: otherJobID)
        let first = try #require(firstJob.workType(id: sharedWorkTypeID))
        let other = try #require(firstJob.workType(id: otherWorkTypeID))
        let second = try #require(secondJob.workType(id: sharedWorkTypeID))
        for (workType, amount) in [(first, 100), (other, 200), (second, 300)] {
            #expect(workType.payRates.map(\.id) == [sharedRateID])
            #expect(workType.payRates.map(\.amount) == [Decimal(amount)])
        }
        let firstShifts = try shifts.loadAll(forJobID: jobID)
        let secondShifts = try shifts.loadAll(forJobID: otherJobID)
        #expect(Set(firstShifts.map(\.id)) == Set(shiftIDs.prefix(2)))
        #expect(secondShifts.map(\.id) == [shiftIDs[2]])
        for (index, typeID, amount) in [(0, sharedWorkTypeID, 100), (1, otherWorkTypeID, 200),
                                        (2, sharedWorkTypeID, 300)] {
            let (job, candidates) = index == 2 ? (secondJob, secondShifts) : (firstJob, firstShifts)
            let shift = try #require(candidates.first { $0.id == shiftIDs[index] })
            #expect(shift.workTypeID == typeID)
            #expect(try job.basePay(for: shift) == Decimal(amount))
        }
    }

    @Test(arguments: StagedChange.allCases)
    private func resumedCandidateMustMatchTheBackup(_ change: StagedChange) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let original = try makeSource(version: 6, fixture: fixture)
        let workspace = PayRateStoreMigrator.workspace(for: original)
        let staged = workspace.appendingPathComponent("staging/store.sqlite")
        let backup = workspace.appendingPathComponent("staging/backup/store.sqlite")

        await #expect(throws: Interrupted.before) {
            try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeActivation = stage { throw Interrupted.before }
            }
        }
        switch change {
        case .rate:
            try Self.editRate(at: staged, version: 7, amount: "999.125")
        case .shift:
            try Self.withStore(at: staged, version: 7) { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: "ShiftEntity")
                let shift = try #require(try context.fetch(request).first)
                context.delete(shift)
                try context.save()
            }
        }

        do {
            _ = try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeActivation = stage { Issue.record("Candidate reached activation") }
            }
            Issue.record("A changed candidate was activated")
        } catch PayRateStoreMigrationError.destinationDiffers {
            #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("active").path))
        }
        #expect(FileManager.default.fileExists(atPath: staged.path))
        for url in [original, backup] {
            try Self.withStore(at: url, version: 6) { context in
                let rates = try context.fetch(NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity"))
                #expect(Set(rates.map { $0.amount.stringValue }) == ["1234.56", "1299.875", "1375.125"])
                let shifts = try context.fetch(NSFetchRequest<ShiftEntity>(entityName: "ShiftEntity"))
                #expect(Set(shifts.map(\.id)) == [
                    fixture.identifiers.sameDayShift, fixture.identifiers.shiftWithBreak, fixture.identifiers.overnightShift
                ])
            }
        }
    }

    @Test(arguments: [false, true])
    func interruptedBeforeSourceIntentRetriesEmptyStaging(_ legacy: Bool) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let original = legacy ? fixture.storeURL :
            fixture.storeURL.deletingLastPathComponent().appendingPathComponent("Fresh.sqlite")
        let staging = PayRateStoreMigrator.workspace(for: original).appendingPathComponent("staging")
        await #expect(throws: Interrupted.beforeSourceIntent) {
            try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeSourceIntent = stage { throw Interrupted.beforeSourceIntent }
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: staging.path).isEmpty)

        let stack = try await CoreDataStack.load(storeURL: original)
        defer { try? close(stack) }
        #expect(try JobStorage(stack: stack).load()?.id == (legacy ? fixture.identifiers.job : nil))
        #expect(!FileManager.default.fileExists(atPath: staging.path))
    }

    @Test(arguments: UninitializedArtifact.allCases)
    private func ambiguousStagingPreservesExistingFiles(_ artifact: UninitializedArtifact) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let workspace = PayRateStoreMigrator.workspace(for: fixture.storeURL)
        let staging = workspace.appendingPathComponent("staging", isDirectory: true)
        let relativePath: String
        switch artifact {
        case .store: relativePath = "store.sqlite"
        case .backup: relativePath = "backup/store.sqlite"
        case .pendingBackup: relativePath = "backup-pending/store.sqlite"
        }
        let stored = staging.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: stored.deletingLastPathComponent(), withIntermediateDirectories: true)
        let model = try PayRateStoreMigrator.model(version: 1)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.replacePersistentStore(at: stored, destinationOptions: nil,
                                               withPersistentStoreFrom: fixture.storeURL, sourceOptions: nil,
                                               ofType: NSSQLiteStoreType)
        if artifact == .pendingBackup {
            try Data("legacy".utf8).write(to: staging.appendingPathComponent("source-kind"))
        }
        let originalBytes = try Data(contentsOf: stored)
        do {
            _ = try await PayRateStoreMigrator.resolve(original: fixture.storeURL)
            Issue.record("Ambiguous staging was activated")
        } catch PayRateStoreMigrationError.incompleteMigration {
            #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("active").path))
            #expect(try Data(contentsOf: stored) == originalBytes)
        }
    }

    @Test
    func invalidDestinationAndFailurePreserveSourceAndAllowRetry() async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .hourly, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let original = fixture.storeURL
        do {
            _ = try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeValidation(let url) = stage {
                    try Self.editRate(at: url, version: 7, amount: "1.004junk")
                }
            }
            Issue.record("Invalid destination was activated")
        } catch PayRateStoreMigrationError.validationFailed(let cause) {
            #expect(cause as? PayRateDecimalCodec.Failure == .nonCanonical)
        }
        let active = PayRateStoreMigrator.workspace(for: original).appendingPathComponent("active", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: active.path))
        await #expect(throws: Interrupted.before) {
            try await PayRateStoreMigrator.resolve(original: original) { stage in
                if case .beforeValidation = stage { throw Interrupted.before }
            }
        }
        let sourceCount = try fixture.inspect { context in
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "PayRateEntity"))
        }
        #expect(sourceCount == 3)
        let selected = try await PayRateStoreMigrator.resolve(original: original)
        #expect(selected.deletingLastPathComponent() == active)
    }

    @Test
    func invalidLegacyAmountPreservesTheBackupAndOriginal() async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        try Self.editRate(at: fixture.storeURL, version: 1, amount: "0")
        do {
            _ = try await PayRateStoreMigrator.resolve(original: fixture.storeURL)
            Issue.record("Invalid legacy amount was activated")
        } catch PayRateStoreMigrationError.validationFailed(let cause) {
            #expect(cause as? PayRateDecimalCodec.Failure == .nonFiniteOrNonPositive)
        }
        let workspace = PayRateStoreMigrator.workspace(for: fixture.storeURL)
        #expect(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("active").path))
        #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("staging/backup/store.sqlite").path))
        let sourceCount = try fixture.inspect { context in
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "PayRateEntity"))
        }
        #expect(sourceCount == 3)
    }

    @Test(arguments: SelectionDamage.allCases)
    private func invalidActiveSelectionNeverFallsBack(_ damage: SelectionDamage) async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let selected = try await PayRateStoreMigrator.resolve(original: fixture.storeURL)
        let selector = selected.deletingLastPathComponent().appendingPathComponent("active-store")
        switch damage {
        case .missingSelector: try FileManager.default.removeItem(at: selector)
        case .corruptSelector: try Data("../ShiftLedger.sqlite".utf8).write(to: selector)
        case .missingStore: try FileManager.default.removeItem(at: selected)
        }
        do {
            _ = try await PayRateStoreMigrator.resolve(original: fixture.storeURL)
            Issue.record("Invalid active selection opened a store")
        } catch PayRateStoreMigrationError.invalidSelection(let actual) {
            #expect(damage != .missingStore)
            #expect(actual == selector)
        } catch PayRateStoreMigrationError.selectedStoreMissing(let actual) {
            #expect(damage == .missingStore)
            #expect(actual == selected)
            #expect(!FileManager.default.fileExists(atPath: selected.path))
        }
        #expect(FileManager.default.fileExists(atPath: fixture.storeURL.path))
    }

    @Test
    func backupRestorationIsExplicitAndLeavesPostMigrationWritesActive() async throws {
        let fixture = try LegacyCoreDataStoreFixture.make(payBasis: .fixedPerShift, payPeriod: .perShift)
        defer { try? fixture.remove() }
        let initial = try await CoreDataStack.load(storeURL: fixture.storeURL)
        let selected = try activeURL(initial)
        let job = try #require(try JobStorage(stack: initial).load())
        let type = try #require(job.soleWorkType)
        let newRate = try PayRate(amount: PayRateDecimalCodec.decode("1.00412345678901234567890123456789"),
                                  effectiveFrom: LocalDate(year: 2030, month: 1, day: 1))
        _ = try JobStorage(stack: initial).addPayRate(newRate, toWorkTypeID: type.id, inJobID: job.id)
        try close(initial)

        let restore = fixture.storeURL.deletingLastPathComponent().appendingPathComponent("Recovered.sqlite")
        try await PayRateStoreMigrator.restoreBackup(original: fixture.storeURL, to: restore)
        let recovered = try await CoreDataStack.load(storeURL: restore)
        defer { try? close(recovered) }
        #expect(try JobStorage(stack: recovered).load() == job)
        let active = try await CoreDataStack.load(storeURL: fixture.storeURL)
        defer { try? close(active) }
        #expect(try activeURL(active) == selected)
        #expect(try JobStorage(stack: active).load()?.soleWorkType?.payRates.last == newRate)
    }

    private func makeSource(version: Int, fixture: LegacyCoreDataStoreFixture.Store) throws -> URL {
        guard version != 1 else { return fixture.storeURL }
        let v1 = try LegacyCoreDataStoreFixture.loadLegacyModel()
        let target = try PayRateStoreMigrator.model(version: version)
        let destination = fixture.storeURL.deletingLastPathComponent().appendingPathComponent("V\(version).sqlite")
        let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: v1, destinationModel: target)
        let manager = NSMigrationManager(sourceModel: v1, destinationModel: target)
        try manager.migrateStore(from: fixture.storeURL, sourceType: NSSQLiteStoreType, options: nil,
                                 with: mapping, toDestinationURL: destination,
                                 destinationType: NSSQLiteStoreType, destinationOptions: nil)
        return destination
    }

    private nonisolated static func insert<T: NSManagedObject>(
        _ type: T.Type, named name: String, in context: NSManagedObjectContext
    ) throws -> T {
        try #require(NSEntityDescription.insertNewObject(forEntityName: name, into: context) as? T)
    }

    private nonisolated static func editRate(at url: URL, version: Int, amount: String) throws {
        try withStore(at: url, version: version) { context in
            let row = try #require(try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "PayRateEntity")).first)
            row.setValue(version == 7 ? amount as Any : NSDecimalNumber(string: amount), forKey: "amount")
            try context.save()
        }
    }

    private nonisolated static func withStore(
        at url: URL, version: Int, _ operation: @Sendable (NSManagedObjectContext) throws -> Void
    ) throws {
        let model = try PayRateStoreMigrator.model(version: version)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let result = context.performAndWait {
            defer { context.reset() }
            return Result { try operation(context) }
        }
        try coordinator.remove(store)
        try result.get()
    }

    private func activeURL(_ stack: CoreDataStack) throws -> URL {
        try #require(stack.viewContext.persistentStoreCoordinator?.persistentStores.first?.url)
    }

    private func close(_ stack: CoreDataStack) throws {
        stack.viewContext.reset()
        let coordinator = try #require(stack.viewContext.persistentStoreCoordinator)
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }
}
