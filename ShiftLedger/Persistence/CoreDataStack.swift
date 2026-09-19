import Foundation
import CoreData

enum CoreDataStackError: Error {
    case persistentStoreLoadFailed(underlying: Error)
    case legacyWorkTypeBackfillFailed(underlying: LegacyWorkTypeBackfillError)
    case legacyShiftWorkTypeBackfillFailed(underlying: LegacyShiftWorkTypeBackfillError)
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
        let persistentContainer = NSPersistentContainer(name: "ShiftLedger")

        if let storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.type = NSSQLiteStoreType
            persistentContainer.persistentStoreDescriptions = [storeDescription]
        }

        try await withCheckedThrowingContinuation(isolation: MainActor.shared) { (continuation: CheckedContinuation<Void, Error>) in
            persistentContainer.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: CoreDataStackError.persistentStoreLoadFailed(underlying: error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        do {
            try LegacyWorkTypeBackfill.run(in: persistentContainer.viewContext)
        } catch {
            throw CoreDataStackError.legacyWorkTypeBackfillFailed(underlying: error)
        }

        do {
            try LegacyShiftWorkTypeBackfill.run(in: persistentContainer.viewContext)
        } catch {
            throw CoreDataStackError.legacyShiftWorkTypeBackfillFailed(underlying: error)
        }

        return CoreDataStack(persistentContainer: persistentContainer)
    }

#if DEBUG
    static func resetPersistentStoreForUITesting() throws {
        let persistentContainer = NSPersistentContainer(name: "ShiftLedger")
        guard
            let storeDescription = persistentContainer.persistentStoreDescriptions.first,
            let storeURL = storeDescription.url
        else {
            return
        }

        let fileManager = FileManager.default
        let storeFiles = [
            storeURL,
            URL(fileURLWithPath: "\(storeURL.path)-wal"),
            URL(fileURLWithPath: "\(storeURL.path)-shm")
        ]
        guard storeFiles.contains(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return
        }

        try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
            at: storeURL,
            ofType: storeDescription.type,
            options: storeDescription.options
        )
    }
#endif
}
