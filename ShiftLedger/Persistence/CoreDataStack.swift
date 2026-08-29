import Foundation
import CoreData

enum CoreDataStackError: Error {
    case persistentStoreLoadFailed(underlying: Error)
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

        return CoreDataStack(persistentContainer: persistentContainer)
    }
}
