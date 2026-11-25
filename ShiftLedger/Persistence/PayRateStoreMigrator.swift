import CoreData
import Foundation

enum PayRateStoreMigrationError: Error {
    case modelUnavailable(version: Int)
    case unknownSourceModel(URL)
    case invalidMapping
    case invalidLegacyAmount
    case invalidSelection(URL)
    case selectedStoreMissing(URL)
    case incompleteMigration(URL)
    case invalidGraph(String)
    case destinationDiffers
    case backupFailed(underlying: Error)
    case migrationFailed(underlying: Error)
    case validationFailed(underlying: Error)
    case activationFailed(underlying: Error)
    case recoveryDestinationOccupied(URL)
}

struct PayRateStoreMigrator {
    enum Checkpoint: Sendable {
        case beforeSourceIntent
        case beforeValidation(URL)
        case beforeActivation
        case afterActivation
    }

    private enum Attribute: Equatable, Sendable {
        case text(String)
        case date(Date)
        case boolean(Bool)
    }

    private enum Identity: Hashable, Sendable {
        case job(UUID)
        case workType(jobID: UUID, id: UUID)
        case payRate(jobID: UUID, workTypeID: UUID, id: UUID)
        case shift(UUID)
    }

    private struct Record: Equatable, Sendable {
        let attributes: [String: Attribute]
        let relationships: [String: Set<Identity>]
    }

    private static let queue = DispatchQueue(label: "ShiftLedger.PayRateStoreMigration", qos: .userInitiated)
    private static let storeName = "store.sqlite"
    private static let selectorName = "active-store"

    private let files = FileManager.default
    private let options: [AnyHashable: Any] = [NSSQLitePragmasOption: ["journal_mode": "WAL"]]
    private let checkpoint: @Sendable (Checkpoint) throws -> Void

    static func workspace(for original: URL) -> URL {
        original.appendingPathExtension("v7")
    }

    static func model(version: Int, bundle: Bundle = .main) throws -> NSManagedObjectModel {
        let name = version == 1 ? "ShiftLedger" : "ShiftLedgerV\(version)"
        guard let folder = bundle.url(forResource: "ShiftLedger", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: folder.appendingPathComponent(name + ".mom")) else {
            throw PayRateStoreMigrationError.modelUnavailable(version: version)
        }
        return model
    }

    static func resolve(
        original: URL,
        checkpoint: @escaping @Sendable (Checkpoint) throws -> Void = { _ in }
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    try Self(checkpoint: checkpoint).resolve(original: original)
                })
            }
        }
    }

    /// Exports the pre-upgrade backup to a separate URL. Selection is a separate, explicit operation.
    static func restoreBackup(original: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    try Self(checkpoint: { _ in }).restoreBackup(original: original, to: destination)
                })
            }
        }
    }

    private func resolve(original: URL) throws -> URL {
        let current = try Self.model(version: 7)
        let workspace = Self.workspace(for: original)
        let active = workspace.appendingPathComponent("active", isDirectory: true)
        let staging = workspace.appendingPathComponent("staging", isDirectory: true)

        if try exists(active) {
            return try selectedStore(in: active, model: current)
        }

        let intent = staging.appendingPathComponent("source-kind")
        let workspaceEntries = try directoryEntriesIfPresent(workspace)
        guard workspaceEntries.isSubset(of: ["staging"]) else {
            throw PayRateStoreMigrationError.incompleteMigration(workspace)
        }
        let entries = try directoryEntriesIfPresent(staging)
        if try !exists(intent) {
            guard entries.isEmpty else {
                throw PayRateStoreMigrationError.incompleteMigration(workspace)
            }
            let hasOriginal = try exists(original)
            if !hasOriginal, try hasStoreFiles(original) {
                throw PayRateStoreMigrationError.selectedStoreMissing(original)
            }
            try files.createDirectory(at: staging, withIntermediateDirectories: true)
            try checkpoint(.beforeSourceIntent)
            try (hasOriginal ? "legacy" : "fresh").write(to: intent, atomically: true, encoding: .utf8)
        }

        let selector = staging.appendingPathComponent(Self.selectorName)
        let candidate = staging.appendingPathComponent(Self.storeName)
        let resumed = try exists(selector)
        if resumed {
            _ = try selectedStore(in: staging, model: current)
        }

        let commonEntries = Set(["source-kind", Self.selectorName])
            .union(Self.sqliteEntries(Self.storeName))
        switch try String(contentsOf: intent, encoding: .utf8) {
        case "legacy":
            guard entries.isSubset(of: commonEntries.union(["backup", "backup-pending", "work"])) else {
                throw PayRateStoreMigrationError.incompleteMigration(staging)
            }
            let backup = staging.appendingPathComponent("backup", isDirectory: true)
            if !entries.contains("backup") {
                // The backup is published before any work or candidate store is created.
                guard !resumed, !entries.contains("work"), try !hasStoreFiles(candidate) else {
                    throw PayRateStoreMigrationError.incompleteMigration(staging)
                }
            } else if entries.contains("backup-pending") {
                throw PayRateStoreMigrationError.incompleteMigration(staging)
            }
            try verifyLegacy(original, staging: staging, backup: backup, candidate: candidate,
                             current: current, resumed: resumed)
        case "fresh":
            guard entries.isSubset(of: commonEntries), try !hasStoreFiles(original) else {
                throw PayRateStoreMigrationError.incompleteMigration(staging)
            }
            if !resumed {
                try discardStagingStore(candidate, model: current)
                try withContext(current, at: candidate) { _ in }
                try checkpoint(.beforeValidation(candidate))
            }
            let destination = try validate(candidate, model: current, legacy: false)
            guard destination.values.allSatisfy(\.isEmpty) else {
                throw PayRateStoreMigrationError.destinationDiffers
            }
        default:
            throw PayRateStoreMigrationError.incompleteMigration(workspace)
        }
        if !resumed {
            try Self.storeName.write(to: selector, atomically: true, encoding: .utf8)
        }

        try checkpoint(.beforeActivation)
        do {
            // Same-volume directory rename publishes the closed SQLite store and selector together.
            try files.moveItem(at: staging, to: active)
        } catch {
            throw PayRateStoreMigrationError.activationFailed(underlying: error)
        }
        try checkpoint(.afterActivation)
        return try selectedStore(in: active, model: current)
    }

    private func verifyLegacy(
        _ original: URL, staging: URL, backup: URL, candidate: URL,
        current: NSManagedObjectModel, resumed: Bool
    ) throws {
        let referenceStore = try createBackup(original, in: staging, backupFolder: backup)
        let (version, sourceModel) = try sourceModel(at: referenceStore)
        let work = staging.appendingPathComponent("work", isDirectory: true)
        if try exists(work) {
            guard try directoryEntriesIfPresent(work).isSubset(of: Self.sqliteEntries("v6.sqlite")) else {
                throw PayRateStoreMigrationError.incompleteMigration(work)
            }
            try files.removeItem(at: work)
        }
        if !resumed {
            try discardStagingStore(candidate, model: current)
        }

        let reference: [String: [Identity: Record]]
        if version == 7 {
            reference = try validate(referenceStore, model: current, legacy: false)
            if !resumed {
                try clone(referenceStore, to: candidate, model: current)
            }
        } else {
            // Reconstruct the same normalized V6 graph for initial and resumed validation.
            try files.createDirectory(at: work, withIntermediateDirectories: false)
            let v6 = try Self.model(version: 6)
            let intermediate = work.appendingPathComponent("v6.sqlite")
            if version == 6 {
                try clone(referenceStore, to: intermediate, model: v6)
            } else {
                let historical = try NSMappingModel.inferredMappingModel(
                    forSourceModel: sourceModel, destinationModel: v6
                )
                try migrate(referenceStore, from: sourceModel, to: intermediate, model: v6, mapping: historical)
            }

            try withContext(v6, at: intermediate) { context in
                do {
                    try LegacyWorkTypeBackfill.run(in: context)
                } catch let error as LegacyWorkTypeBackfillError {
                    throw CoreDataStackError.legacyWorkTypeBackfillFailed(underlying: error)
                }
                do {
                    try LegacyShiftWorkTypeBackfill.run(in: context)
                } catch let error as LegacyShiftWorkTypeBackfillError {
                    throw CoreDataStackError.legacyShiftWorkTypeBackfillFailed(underlying: error)
                }
            }
            reference = try validate(intermediate, model: v6, legacy: true)
            if !resumed {
                try migrate(intermediate, from: v6, to: candidate, model: current,
                            mapping: Self.amountMapping(from: v6, to: current))
            }
            try files.removeItem(at: work)
        }

        if !resumed {
            try checkpoint(.beforeValidation(candidate))
        }
        let destination = try validate(candidate, model: current, legacy: false)
        guard destination == reference else { throw PayRateStoreMigrationError.destinationDiffers }
    }

    private func selectedStore(in directory: URL, model: NSManagedObjectModel) throws -> URL {
        let selector = directory.appendingPathComponent(Self.selectorName)
        guard let data = try? Data(contentsOf: selector), data == Data(Self.storeName.utf8) else {
            throw PayRateStoreMigrationError.invalidSelection(selector)
        }
        let url = directory.appendingPathComponent(Self.storeName)
        guard try exists(url) else { throw PayRateStoreMigrationError.selectedStoreMissing(url) }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url
        )
        guard model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
            throw PayRateStoreMigrationError.invalidSelection(selector)
        }
        return url
    }

    private func createBackup(_ original: URL, in staging: URL, backupFolder: URL) throws -> URL {
        let backup = backupFolder.appendingPathComponent(Self.storeName)
        if try exists(backupFolder) {
            guard try directoryEntriesIfPresent(backupFolder).isSubset(of: Self.sqliteEntries(Self.storeName)),
                  try exists(backup) else {
                throw PayRateStoreMigrationError.incompleteMigration(backupFolder)
            }
            return backup
        }

        guard try exists(original) else { throw PayRateStoreMigrationError.selectedStoreMissing(original) }
        let pending = staging.appendingPathComponent("backup-pending", isDirectory: true)
        guard try directoryEntriesIfPresent(pending).isEmpty else {
            throw PayRateStoreMigrationError.incompleteMigration(pending)
        }
        do {
            try files.createDirectory(at: pending, withIntermediateDirectories: true)
            let (_, model) = try sourceModel(at: original)
            try clone(original, to: pending.appendingPathComponent(Self.storeName), model: model)
            try files.moveItem(at: pending, to: backupFolder)
            return backup
        } catch {
            throw PayRateStoreMigrationError.backupFailed(underlying: error)
        }
    }

    private func restoreBackup(original: URL, to destination: URL) throws {
        guard try !hasStoreFiles(destination) else {
            throw PayRateStoreMigrationError.recoveryDestinationOccupied(destination)
        }
        let backup = Self.workspace(for: original).appendingPathComponent("active/backup/\(Self.storeName)")
        guard try exists(backup) else { throw PayRateStoreMigrationError.selectedStoreMissing(backup) }
        let (version, model) = try sourceModel(at: backup)
        try clone(backup, to: destination, model: model)
        let (restoredVersion, _) = try sourceModel(at: destination)
        guard restoredVersion == version else { throw PayRateStoreMigrationError.destinationDiffers }
    }

    private func sourceModel(at url: URL) throws -> (Int, NSManagedObjectModel) {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url
        )
        for version in (1...7).reversed() {
            let model = try Self.model(version: version)
            if model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                return (version, model)
            }
        }
        throw PayRateStoreMigrationError.unknownSourceModel(url)
    }

    private func exists(_ url: URL) throws -> Bool {
        do {
            _ = try files.attributesOfItem(atPath: url.path)
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        }
    }

    private func directoryEntriesIfPresent(_ directory: URL) throws -> Set<String> {
        guard try exists(directory) else { return [] }
        let attributes = try files.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw PayRateStoreMigrationError.incompleteMigration(directory)
        }
        return try Set(files.contentsOfDirectory(atPath: directory.path))
    }

    private static func sqliteEntries(_ name: String) -> Set<String> {
        [name, name + "-wal", name + "-shm"]
    }

    private func hasStoreFiles(_ url: URL) throws -> Bool {
        try [url.path, url.path + "-wal", url.path + "-shm"].contains {
            try exists(URL(fileURLWithPath: $0))
        }
    }

    private func discardStagingStore(_ url: URL, model: NSManagedObjectModel) throws {
        // This URL is confined to staging without a published selector.
        if try hasStoreFiles(url) {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType)
        }
    }

    private func clone(_ source: URL, to destination: URL, model: NSManagedObjectModel) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.replacePersistentStore(
            at: destination, destinationOptions: options, withPersistentStoreFrom: source,
            sourceOptions: options, ofType: NSSQLiteStoreType
        )
    }

    private func migrate(_ source: URL, from sourceModel: NSManagedObjectModel, to destination: URL,
                         model: NSManagedObjectModel, mapping: NSMappingModel) throws {
        do {
            let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: model)
            try manager.migrateStore(from: source, sourceType: NSSQLiteStoreType, options: options,
                                     with: mapping, toDestinationURL: destination,
                                     destinationType: NSSQLiteStoreType, destinationOptions: options)
        } catch {
            throw PayRateStoreMigrationError.migrationFailed(underlying: error)
        }
    }

    private func withContext<T: Sendable>(
        _ model: NSManagedObjectModel, at url: URL,
        _ body: @Sendable (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: options)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let result = context.performAndWait {
            defer { context.reset() }
            return Result { try body(context) }
        }
        try coordinator.remove(store)
        return try result.get()
    }

    private func validate(_ url: URL, model: NSManagedObjectModel, legacy: Bool) throws -> [String: [Identity: Record]] {
        do {
            guard try exists(url) else { throw PayRateStoreMigrationError.selectedStoreMissing(url) }
            return try withContext(model, at: url) { context in
                try Self.snapshot(context: context, legacy: legacy)
            }
        } catch {
            throw PayRateStoreMigrationError.validationFailed(underlying: error)
        }
    }

    private static func snapshot(
        context: NSManagedObjectContext, legacy: Bool
    ) throws -> [String: [Identity: Record]] {
        guard let model = context.persistentStoreCoordinator?.managedObjectModel else {
            throw PayRateStoreMigrationError.invalidMapping
        }
        var result: [String: [Identity: Record]] = [:]
        for entity in model.entities {
            guard let name = entity.name else { throw PayRateStoreMigrationError.invalidMapping }
            var rows: [Identity: Record] = [:]
            for row in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
                let id = try identity(row)
                guard rows[id] == nil else { throw PayRateStoreMigrationError.invalidGraph(name) }
                var attributes: [String: Attribute] = [:]
                for (key, attribute) in entity.attributesByName where key != "id" {
                    guard let stored = row.value(forKey: key) else {
                        if attribute.isOptional { continue }
                        throw PayRateStoreMigrationError.invalidGraph("\(name).\(key)")
                    }
                    if name == "PayRateEntity", key == "amount" {
                        if legacy, let old = stored as? NSDecimalNumber {
                            attributes[key] = .text(try PayRateDecimalCodec.encode(old.decimalValue))
                        } else if !legacy, let text = stored as? String {
                            _ = try PayRateDecimalCodec.decode(text)
                            attributes[key] = .text(text)
                        } else {
                            throw PayRateStoreMigrationError.invalidGraph("\(name).amount")
                        }
                    } else if let text = stored as? String {
                        attributes[key] = .text(text)
                    } else if let date = stored as? Date {
                        attributes[key] = .date(date)
                    } else if let boolean = stored as? NSNumber, attribute.attributeType == .booleanAttributeType {
                        attributes[key] = .boolean(boolean.boolValue)
                    } else {
                        throw PayRateStoreMigrationError.invalidGraph("\(name).\(key)")
                    }
                }

                var relationships: [String: Set<Identity>] = [:]
                for (key, relation) in entity.relationshipsByName {
                    let stored = row.value(forKey: key)
                    let objects: [NSManagedObject]
                    if relation.isToMany {
                        guard let members = stored as? Set<NSManagedObject> else {
                            if stored == nil, relation.isOptional { continue }
                            throw PayRateStoreMigrationError.invalidGraph("\(name).\(key)")
                        }
                        objects = Array(members)
                    } else {
                        objects = (stored as? NSManagedObject).map { [$0] } ?? []
                    }
                    if objects.count < relation.minCount {
                        throw PayRateStoreMigrationError.invalidGraph("\(name).\(key)")
                    }
                    relationships[key] = try Set(objects.map(identity))
                }
                rows[id] = Record(attributes: attributes, relationships: relationships)
            }
            result[name] = rows
        }
        return result
    }

    private static func identity(_ object: NSManagedObject) throws -> Identity {
        let id = try uuid(of: object)
        switch object.entity.name {
        case "JobEntity":
            return .job(id)
        case "WorkTypeEntity":
            guard let job = object.value(forKey: "job") as? NSManagedObject else {
                throw PayRateStoreMigrationError.invalidGraph("WorkTypeEntity.job")
            }
            return .workType(jobID: try uuid(of: job), id: id)
        case "PayRateEntity":
            let (job, workType) = try owners(of: object)
            return .payRate(jobID: try uuid(of: job), workTypeID: try uuid(of: workType), id: id)
        case "ShiftEntity":
            _ = try owners(of: object)
            return .shift(id)
        default:
            throw PayRateStoreMigrationError.invalidMapping
        }
    }

    private static func uuid(of object: NSManagedObject) throws -> UUID {
        guard let id = object.value(forKey: "id") as? UUID else {
            throw PayRateStoreMigrationError.invalidGraph(object.entity.name ?? "id")
        }
        return id
    }

    private static func owners(of object: NSManagedObject) throws -> (NSManagedObject, NSManagedObject) {
        guard let job = object.value(forKey: "job") as? NSManagedObject,
              let workType = object.value(forKey: "workType") as? NSManagedObject,
              let owner = workType.value(forKey: "job") as? NSManagedObject,
              owner === job else {
            throw PayRateStoreMigrationError.invalidGraph("\(object.entity.name ?? "Unknown").workType")
        }
        return (job, workType)
    }

    private static func amountMapping(
        from source: NSManagedObjectModel, to destination: NSManagedObjectModel
    ) throws -> NSMappingModel {
        let mapping = NSMappingModel()
        mapping.entityMappings = try source.entities.map { entity in
            guard let name = entity.name, let target = destination.entitiesByName[name] else {
                throw PayRateStoreMigrationError.invalidMapping
            }
            let entry = NSEntityMapping()
            entry.name = name
            entry.mappingType = .customEntityMappingType
            entry.sourceEntityName = name
            entry.destinationEntityName = name
            entry.sourceEntityVersionHash = entity.versionHash
            entry.destinationEntityVersionHash = target.versionHash
            entry.sourceExpression = NSFetchRequestExpression.expression(
                forFetch: NSExpression(
                    format: "FUNCTION($manager, 'fetchRequestForSourceEntityNamed:predicateString:', %@, 'TRUEPREDICATE')",
                    name
                ),
                context: NSExpression(format: "$manager.sourceContext"), countOnly: false
            )
            entry.attributeMappings = entity.attributesByName.keys.sorted()
                .filter { name != "PayRateEntity" || $0 != "amount" }
                .map { propertyMapping($0, expression: NSExpression(format: "$source.%K", $0)) }
            entry.relationshipMappings = try entity.relationshipsByName.keys.sorted().map { key in
                guard let related = entity.relationshipsByName[key]?.destinationEntity?.name else {
                    throw PayRateStoreMigrationError.invalidMapping
                }
                return propertyMapping(key, expression: NSExpression(
                    format: "FUNCTION($manager, 'destinationInstancesForEntityMappingNamed:sourceInstances:', %@, $source.%K)",
                    related, key
                ))
            }
            if name == "PayRateEntity" {
                entry.entityMigrationPolicyClassName = NSStringFromClass(PayRateAmountMigrationPolicy.self)
            }
            return entry
        }
        return mapping
    }

    private static func propertyMapping(_ key: String, expression: NSExpression) -> NSPropertyMapping {
        let mapping = NSPropertyMapping()
        mapping.name = key
        mapping.valueExpression = expression
        return mapping
    }
}
