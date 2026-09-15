import Foundation
import CoreData
import Testing
@testable import ShiftLedger

@MainActor
struct AppLaunchResolverTests {

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

        #expect(resolution.stack === stack)
        #expect(resolution.job == nil)
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
        let resolvedJob = try #require(resolution.job)

        #expect(resolution.stack === stack)
        #expect(resolvedJob.id == job.id)
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
