import Foundation
import CoreData

enum CoreDataStackError: Error {
    case persistentStoreLoadFailed(underlying: Error)
    case persistentStoreMigrationFailed(underlying: Error)
    case legacyWorkTypeBackfillFailed(underlying: LegacyWorkTypeBackfillError)
    case legacyShiftWorkTypeBackfillFailed(underlying: LegacyShiftWorkTypeBackfillError)
    case missingStoreLocation
    case testStoreRequired
}

@MainActor
final class CoreDataStack {
    let viewContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer

    private init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        viewContext = persistentContainer.viewContext
    }

    static func load(storeURL: URL? = nil) async throws -> CoreDataStack {
        let container = NSPersistentContainer(name: "ShiftLedger", managedObjectModel: try PayRateStoreMigrator.model(version: 7))
        guard let defaultURL = container.persistentStoreDescriptions.first?.url else {
            throw CoreDataStackError.missingStoreLocation
        }
        let original = storeURL ?? defaultStoreURL(defaultURL)
        let active: URL
        do {
            active = try await PayRateStoreMigrator.resolve(original: original)
        } catch let error as CoreDataStackError {
            throw error
        } catch {
            throw CoreDataStackError.persistentStoreMigrationFailed(underlying: error)
        }

        let description = NSPersistentStoreDescription(url: active)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        description.shouldAddStoreAsynchronously = true
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation(isolation: MainActor.shared) { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: CoreDataStackError.persistentStoreLoadFailed(underlying: error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return CoreDataStack(persistentContainer: container)
    }

    private static func defaultStoreURL(_ url: URL) -> URL {
#if DEBUG
        if ProcessInfo.processInfo.environment["SHIFTLEDGER_UI_TEST_STORE"] == "1" {
            return url.deletingLastPathComponent()
                .appendingPathComponent("ShiftLedgerUITestStore", isDirectory: true)
                .appendingPathComponent(url.lastPathComponent)
        }
#endif
        return url
    }

#if DEBUG
    static func resetPersistentStoreForUITesting() throws {
        guard ProcessInfo.processInfo.environment["SHIFTLEDGER_UI_TEST_STORE"] == "1" else {
            throw CoreDataStackError.testStoreRequired
        }
        guard let url = NSPersistentContainer(name: "ShiftLedger").persistentStoreDescriptions.first?.url else {
            throw CoreDataStackError.missingStoreLocation
        }
        let directory = defaultStoreURL(url).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
#endif
}
