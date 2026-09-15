import Foundation

@MainActor
struct AppLaunchResolution {
    let stack: CoreDataStack
    let job: Job?
}

@MainActor
final class AppLaunchResolver {
    private let loadCoreDataStack: @MainActor () async throws -> CoreDataStack

    init(
        loadCoreDataStack: @escaping @MainActor () async throws -> CoreDataStack = {
            try await CoreDataStack.load()
        }
    ) {
        self.loadCoreDataStack = loadCoreDataStack
    }

    func resolve() async throws -> AppLaunchResolution {
        try prepareLaunchStateForUITesting()

        let stack = try await loadCoreDataStack()
        try Task.checkCancellation()

        let job = try loadInitialJob(from: stack)

        return AppLaunchResolution(
            stack: stack,
            job: job
        )
    }

    private func prepareLaunchStateForUITesting() throws {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-store") {
            try CoreDataStack.resetPersistentStoreForUITesting()
        }
#endif
    }

    private func loadInitialJob(from stack: CoreDataStack) throws -> Job? {
        let jobStorage = JobStorage(stack: stack)

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-seed-job"),
           try jobStorage.load() == nil {
            let job = try Job(
                currencyCode: "SEK",
                timeZoneIdentifier: "Europe/Stockholm",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: [
                    try PayRate(
                        amount: 100,
                        effectiveFrom: nil
                    )
                ],
                createdAt: Date(timeIntervalSinceReferenceDate: 0)
            )
            try jobStorage.save(job)
        }
#endif

        return try jobStorage.load()
    }
}
