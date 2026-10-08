import Foundation
import CoreData
import Testing
@testable import ShiftLedger

@MainActor
struct AppLaunchResolverTests {

    @Test("Launch destination counts active Jobs only", arguments: [
        (0, 0), (1, 0), (1, 2), (2, 0), (3, 1), (0, 2)
    ])
    func launchDestination(active: Int, archived: Int) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { try? fixture.close() }
        for index in 0..<(active + archived) {
            try fixture.insertJob(index: index + 1, archived: index >= active)
        }
        let catalog = try JobStorage(stack: fixture.stack).loadCatalog()
        let resolver = AppLaunchResolver(loadCoreDataStack: { fixture.stack }, arguments: [])
        let result = try await resolver.resolve()
        if catalog.isEmpty {
            #expect(result.destination == .onboarding)
        } else if active == 1 {
            #expect(result.destination == .main(try #require(catalog.first { !$0.isArchived }).job))
        } else {
            #expect(result.destination == .jobSelection(catalog))
        }
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Duplicate catalog identity fails launch before choosing any Job")
    func duplicateCatalogFailsLaunch() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { try? fixture.close() }
        let first = try fixture.insertJob(index: 1)
        let second = try fixture.insertJob(index: 2)
        second.id = first.id
        try fixture.stack.viewContext.save()
        do {
            _ = try await AppLaunchResolver(loadCoreDataStack: { fixture.stack }, arguments: []).resolve()
            Issue.record("Duplicate catalog was accepted")
        } catch JobStorageError.corruptedData(.duplicateJobIdentity(let id)) {
            #expect(id == first.id)
        }
    }

    @Test("Corrupted archived Job fails the full launch catalog")
    func corruptedCatalogFailsLaunch() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { try? fixture.close() }
        try fixture.insertJob(index: 1)
        let archived = try fixture.insertJob(index: 2, archived: true)
        archived.timeZoneIdentifier = "Invalid/Zone"
        try fixture.stack.viewContext.save()
        do {
            _ = try await AppLaunchResolver(loadCoreDataStack: { fixture.stack }, arguments: []).resolve()
            Issue.record("Corrupted catalog was accepted")
        } catch JobStorageError.corruptedData(.invalidTimeZoneIdentifier(let identifier)) {
            #expect(identifier == "Invalid/Zone")
        }
    }

    @Test("Selection revalidation returns exact typed ownership failures", arguments: ["missing", "archived", "duplicate"])
    func selectedIdentityIsRevalidated(reason: String) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { try? fixture.close() }
        let first = try fixture.insertJob(index: 1)
        let second = try fixture.insertJob(index: 2)
        let id = first.id
        let composition = AppFlowComposition(stack: fixture.stack)
        #expect(try composition.resolveSelectedJob(id: id).id == id)
        switch reason {
        case "missing": fixture.stack.viewContext.delete(first)
        case "archived": first.isArchived = true
        default: second.id = id
        }
        try fixture.stack.viewContext.save()
        do {
            _ = try composition.resolveSelectedJob(id: id)
            Issue.record("Invalid selected identity was accepted")
        } catch JobSelectionError.jobNotFound(let failedID) {
            #expect(reason == "missing")
            #expect(failedID == id)
        } catch JobSelectionError.jobArchived(let failedID) {
            #expect(reason == "archived")
            #expect(failedID == id)
        } catch JobStorageError.corruptedData(.duplicateJobIdentity(let failedID)) {
            #expect(reason == "duplicate")
            #expect(failedID == id)
        }
        #expect(!fixture.stack.viewContext.hasChanges)
    }

#if DEBUG
    @Test("Debug seed only inserts into an empty catalog", arguments: [0, 2])
    func debugSeedRequiresEmptyCatalog(existingCount: Int) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { try? fixture.close() }
        for index in 0..<existingCount { try fixture.insertJob(index: index + 1) }
        let resolver = AppLaunchResolver(
            loadCoreDataStack: { fixture.stack }, arguments: ["-ui-testing-seed-job"]
        )
        let first = try await resolver.resolve()
        let second = try await resolver.resolve()
        #expect(first.destination == second.destination)
        #expect(try JobStorage(stack: fixture.stack).loadCatalog().count == max(1, existingCount))
    }
#endif

    @Test("Empty store resolves with no Job")
    func emptyStoreResolvesWithoutJob() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)

        defer {
            removeTemporaryStoreDirectory(
                for: storeURL,
                stack: stack
            )
        }

        let resolver = AppLaunchResolver(
            loadCoreDataStack: { stack }
        )

        let resolution = try await resolver.resolve()

        #expect(resolution.destination == .onboarding)
    }

    @Test("Persisted Job is returned in launch resolution")
    func persistedJobIsReturned() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)

        defer {
            removeTemporaryStoreDirectory(
                for: storeURL,
                stack: stack
            )
        }

        let job = try makeValidJob()
        try JobStorage(stack: stack).save(job)

        let resolver = AppLaunchResolver(
            loadCoreDataStack: { stack }
        )

        let resolution = try await resolver.resolve()
        #expect(resolution.destination == .main(job))
    }

    @Test("Cancellation is checked after Core Data stack loading")
    func cancellationStopsResolutionAfterStackLoad() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)

        defer {
            removeTemporaryStoreDirectory(
                for: storeURL,
                stack: stack
            )
        }

        var loadCallCount = 0
        var finishLoading: CheckedContinuation<CoreDataStack, Never>?

        let resolver = AppLaunchResolver(
            loadCoreDataStack: {
                loadCallCount += 1

                return await withCheckedContinuation { continuation in
                    finishLoading = continuation
                }
            }
        )

        let task = Task { @MainActor in
            try await resolver.resolve()
        }

        while finishLoading == nil {
            await Task.yield()
        }

        #expect(loadCallCount == 1)

        task.cancel()

        finishLoading?.resume(returning: stack)
        finishLoading = nil

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ShiftLedgerLaunchResolverTests",
                isDirectory: true
            )
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func makeValidJob() throws -> Job {
        try Job(
            id: try #require(
                UUID(
                    uuidString: "A0000000-0000-0000-0000-000000000001"
                )
            ),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [
                try PayRate(
                    amount: 100,
                    effectiveFrom: nil
                )
            ],
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
    }

    private func removeTemporaryStoreDirectory(
        for storeURL: URL,
        stack: CoreDataStack
    ) {
        let context = stack.viewContext
        context.reset()

        if let coordinator = context.persistentStoreCoordinator {
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }

        try? FileManager.default.removeItem(
            at: storeURL.deletingLastPathComponent()
        )
    }
}
